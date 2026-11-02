#!/bin/sh
# Mount only tests/docs. Production app, R, data and migrations come from image.
set -eu
python -m pip install --quiet --target /tmp/qa-deps 'jsonschema>=4.23,<5'
ln -s /app/migrations /qa/backend/migrations
export PYTHONPATH=/app:/tmp/qa-deps
export PYTHONDONTWRITEBYTECODE=1
python -m pytest -p no:cacheprovider /qa/backend/tests/test_auth_migration_chain.py /qa/backend/tests/test_growth_v2.py -q
