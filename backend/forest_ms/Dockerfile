# backend/forest_ms/Dockerfile
FROM python:3.11-slim

WORKDIR /app

# PostGIS client libs nécessaires pour asyncpg + geodjango/geoalchemy
RUN apt-get update && apt-get install -y \
    libgdal-dev \
    gdal-bin \
    libgeos-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --timeout=300 -r requirements.txt

COPY . .

CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8002"]