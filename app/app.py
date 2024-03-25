from flask import Flask, Response, request

import worker

app = Flask(__name__)

@app.route("/collect", methods=["POST"])
def collect():
    batch = request.json.get("batch")
    if batch:
       worker.write_to_db.delay(batch)
    return Response(status=201)
