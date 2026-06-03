FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y \
    libgdal-dev gdal-bin libgeos-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["sh", "-c", "until pg_isready -h alert_db -p 5432 -U alert_user; do echo 'Waiting for DB...'; sleep 2; done && alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8003"]