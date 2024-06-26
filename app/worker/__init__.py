import os
from celery import Celery
import datetime
import psycopg2
import requests
import urllib
from flask import Flask, Response, request
from mixpanel import Mixpanel


app = Celery('worker', broker="redis://redis/0", backend="redis://redis/1")


def connect_db():
  POSTGRES_USER = os.environ["POSTGRES_USER"]
  POSTGRES_PASSWORD = os.environ["POSTGRES_PASSWORD"]
  POSTGRES_DATABASE = os.environ["POSTGRES_DATABASE"]
  POSTGRES_HOST = os.environ["POSTGRES_HOST"]
  return psycopg2.connect(f"dbname='{POSTGRES_DATABASE}' user='{POSTGRES_USER}' host='{POSTGRES_HOST}' password='{POSTGRES_PASSWORD}'")


def build_sql(utc_time, session_id, user_id, user_ip, username, user_agent, referrer, country, category, action, label, campaign, value):
    if not utc_time:
        dt = datetime.datetime.now(datetime.timezone.utc)
        utc_time = dt.replace(tzinfo=datetime.timezone.utc).timestamp()
    values = [ ("'" + (s or "") + "'") for s in [session_id, user_id, user_ip, username, user_agent, referrer, country, category, action, label, campaign, value]]
    values = ['to_timestamp(' + str(utc_time / 1000) + ')'] + values
    return "insert into events (time, session_id, user_id, ip_address, username, user_agent, referrer, country, category, action, label, campaign, value) values(" + ",".join(values) + ");"


def collect_events(events):
    conn = connect_db()

    with conn.cursor() as curs:
      for j in events:
          sql = build_sql(
              j.get("time"),
              j["cid"],
              j.get("uid"),
              j["uip"],
              j["username"],
              j.get("ua",""),
              j.get("dr",""),
              j["country"],
              j["ec"],
              j["ea"],
              j["el"],
              j.get("cs"),
              j.get("ev")
          )
          curs.execute(sql)

    conn.commit()
    conn.close()


@app.task(bind=True)
def write_to_db(self, events):
  collect_events(events)


@app.task(bind=True)
def collect_mixpanel(self, j):
  return
  mp = Mixpanel('1cb5fbf574011424e06511722b459b75')
  mp.track(j["uid"], j["ec"] + ": " + j["ea"], {
    "label": j["el"],
    "referrer": j.get("dr",""),
    "country": j["country"],
    "user_agent": j.get("ua"),
    "username": j["username"],
    "ip": j["uip"],
    "session_id": j["cid"]
  })
  if(j["username"] != "anonymous"):
    mp.people_set(j["uid"], { "$name": j["username"], "$region": j["country"], "is_anonymous": False})
  else:
    mp.people_set(j["uid"], { "$name": "anon" + j["uid"], "$region": j["country"], "is_anonymous": True})


@app.task(bind=True)
def collect_google_analytics(self, j):
    return
    gadata = {k:j[k] for k in j if k not in ["username", "country"]}
    data = urllib.parse.urlencode(gadata)
    result = requests.post("https://www.google-analytics.com/collect", data, headers={
      "User-Agent": "Kosmi-Collector",
      "Content-Type": "application/x-www-form-urlencoded"
    })


__all__ = ['app']
