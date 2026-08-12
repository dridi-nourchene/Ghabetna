FROM python:3.12-slim

WORKDIR /app

# Dependances systeme minimales pour torch
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl \
 && rm -rf /var/lib/apt/lists/*

# Les dependances AVANT le code : cette couche est mise en cache par Docker
# et n'est reconstruite que si requirements.txt change.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY rag/ ./rag/
COPY app/ ./app/
COPY scripts/ ./scripts/

# Le modele bge-m3 (2.2 Go) est monte en volume, PAS copie dans l'image :
# sans cela il serait retelecharge a chaque reconstruction.
ENV HF_HOME=/root/.cache/huggingface
ENV PYTHONUNBUFFERED=1

EXPOSE 8005

# uvicorn sans --reload : le rechargement automatique relancerait le
# chargement du modele (20 s) a chaque modification de fichier.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8005"]