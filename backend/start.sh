#!/bin/sh
set -eu

alembic upgrade head

exec uvicorn app.main:api --host 0.0.0.0 --port "${PORT:-10000}" --workers 1
