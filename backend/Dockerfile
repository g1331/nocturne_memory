FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY backend/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

COPY backend /app/backend
COPY demo.db /app/demo.db

RUN chmod +x /app/backend/docker-entrypoint.sh

WORKDIR /app/backend
ENTRYPOINT ["/app/backend/docker-entrypoint.sh"]

