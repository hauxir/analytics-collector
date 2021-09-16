from flask import Flask, Response, request

import worker

app = Flask(__name__)

@app.route("/collect", methods=["POST"])
def collect():

    worker.write_to_db.delay(request.json)
    worker.collect_mixpanel.delay(request.json)
    worker.collect_google_analytics.delay(request.json)

    return Response(status=201)
