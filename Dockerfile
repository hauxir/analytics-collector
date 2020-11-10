FROM python:3.6-slim

COPY requirements.txt .

RUN pip install -r requirements.txt

EXPOSE 5000

COPY app /app

WORKDIR /app

CMD bash entrypoint.sh
