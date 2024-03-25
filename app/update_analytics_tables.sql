SELECT 'Retrofitting signed up users...' AS msg;
update events set username=q.username  from (select user_id, string_agg(distinct(case username when 'anonymous' then '' else username end), '') as username, count(distinct(username)) as c from events where time >= now() - interval '3 days' group by user_id)
 as q where q.c > 1 and q.user_id=events.user_id;

SELECT 'Updating sessions...' AS msg;
INSERT INTO sessions
  (session_id, user_id, ip_address, country, user_agent, username,START,"end", referrer)
  SELECT session_id,
         max(user_id),
         max(ip_address),
         max(country),
         max(user_agent),
         max(username),
         min(TIME),
         max(TIME),
         max(referrer)
  FROM EVENTS
  WHERE TIME>=now() - interval '3 days'
  GROUP BY session_id
  ON conflict(session_id) DO UPDATE SET "end"=excluded.end;


SELECT 'Updating sessions.first_session_of_user_id...' AS msg;
WITH RecentSessions AS (
  SELECT
    session_id,
    user_id,
    start,
    first_session_of_user_id,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY start ASC) AS session_rank
  FROM
    sessions
)
UPDATE sessions
SET first_session_of_user_id = (CASE WHEN session_rank = 1 THEN TRUE ELSE FALSE END)
FROM RecentSessions
WHERE sessions.session_id = RecentSessions.session_id
  AND sessions.first_session_of_user_id IS NULL;
  
  
SELECT 'Updating sessions.first_session_of_ip_address...' AS msg;
WITH RecentIPSessions AS (
  SELECT
    session_id,
    ip_address,
    start,
    first_session_of_ip_address,
    ROW_NUMBER() OVER (PARTITION BY ip_address ORDER BY start ASC) AS session_rank
  FROM
    sessions
)
UPDATE sessions
SET first_session_of_ip_address = (CASE WHEN session_rank = 1 THEN TRUE ELSE FALSE END)
FROM RecentIPSessions
WHERE sessions.session_id = RecentIPSessions.session_id
  AND sessions.first_session_of_ip_address IS NULL;


SELECT 'Updating visits...' AS msg;
INSERT INTO visits (user_id, username, "date", country, user_agent, duration, first_visit_of_user_id, first_visit_of_ip_address, referrer)
  SELECT user_id,
         Max(username),
         START::date,
         max(country),
         max(user_agent),
         sum(duration),
         bool_or(first_session_of_user_id),
         bool_or(first_session_of_ip_address),
         max(referrer)
  FROM sessions
  WHERE START>=now() - interval '3 days'
  GROUP BY (user_id,start::date)
  ON CONFLICT ON CONSTRAINT visits_user_id_date_key DO UPDATE SET duration=excluded.duration;

SELECT 'Updating visits(user_id_first_seen)...' AS msg;
WITH first_visits AS (
  SELECT user_id, MIN(date) AS first_seen
  FROM visits
  WHERE first_visit_of_user_id = 't'
  GROUP BY user_id
)
UPDATE visits
SET user_id_first_seen = first_visits.first_seen
FROM first_visits
WHERE visits.user_id = first_visits.user_id
AND visits.user_id_first_seen IS NULL;

SELECT 'Updating visits(days_since_last_visit)...' AS msg;
WITH ranked_visits AS (
  SELECT
    user_id,
    date,
    LAG(date) OVER (PARTITION BY user_id ORDER BY date) AS prev_date
  FROM visits
)
UPDATE visits v
SET days_since_last_visit = v.date - rv.prev_date
FROM ranked_visits rv
WHERE v.user_id = rv.user_id
AND v.date = rv.date
AND rv.prev_date IS NOT NULL;

REFRESH MATERIALIZED VIEW core_users;
REFRESH MATERIALIZED VIEW weekly_visits;
REFRESH MATERIALIZED VIEW monthly_visits;

REFRESH MATERIALIZED VIEW weekly_retention;
REFRESH MATERIALIZED VIEW monthly_retention;
REFRESH MATERIALIZED VIEW all_user_monthly_retention;
REFRESH MATERIALIZED VIEW all_user_weekly_retention;
