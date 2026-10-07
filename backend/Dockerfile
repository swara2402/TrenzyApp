FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd --system trenzy \
  && useradd --system --gid trenzy --create-home trenzy

COPY requirements.txt ./requirements.txt
# Install CPU-only PyTorch first to avoid large CUDA downloads
RUN pip install --no-cache-dir "torch>=2.0.0,<3.0.0" --index-url https://download.pytorch.org/whl/cpu
# Install remaining requirements
RUN pip install --no-cache-dir -r requirements.txt

# Firebase credentials are provided at runtime via FIREBASE_SERVICE_ACCOUNT_JSON
# environment variable or FIREBASE_SERVICE_ACCOUNT_FILE pointing to a mounted
# volume. Never bake service account keys into the image.

COPY app ./app
COPY migrations ./migrations
COPY alembic.ini ./alembic.ini
COPY data ./data
COPY ml ./ml

# Ensure non-root ownership
RUN chown -R trenzy:trenzy /app

USER trenzy

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS http://127.0.0.1:\${PORT}/api/health/live || exit 1

# One worker is intentional for the 512 MB beta instance. Multiple workers
# duplicate Python/ML memory and can exceed the free Render memory limit.
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:api --host 0.0.0.0 --port \${PORT} --workers 1"]