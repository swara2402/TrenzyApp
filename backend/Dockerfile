FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
  && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY app/google-services.json /app/google-services.json
COPY app ./app

EXPOSE 8000

ENV PORT=8000

CMD ["sh", "-c", "uvicorn app.main:api --host 0.0.0.0 --port ${PORT}"]
