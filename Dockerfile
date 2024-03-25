FROM python:3.6-slim

COPY requirements.txt .

RUN pip install -r requirements.txt
RUN apt-get update && apt-get install -y postgresql-client

EXPOSE 5000
EXPOSE 8000

COPY app /app

RUN ln /app/update_analytics_tables.sh /usr/bin/update_analytics_tables
RUN chmod +x /usr/bin/update_analytics_tables

WORKDIR /app

CMD bash entrypoint.sh
