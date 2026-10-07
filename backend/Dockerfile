FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=10000

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd --system trenzy \
  && useradd --system --gid trenzy --create-home trenzy

COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir "torch>=2.0.0,<3.0.0" --index-url https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY migrations ./migrations
COPY alembic.ini ./alembic.ini
COPY data ./data
COPY ml ./ml
COPY start.sh ./start.sh

RUN chmod +x /app/start.sh && chown -R trenzy:trenzy /app

USER trenzy

EXPOSE 10000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS http://127.0.0.1:${PORT}/api/health/live || exit 1

# Keep startup in the image entrypoint so a malformed Render Docker Command
# cannot replace the actual application startup sequence.
ENTRYPOINT ["/app/start.sh"]
