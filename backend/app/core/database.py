"""A connection context commits on success and rolls back on exceptions."""
import os
from contextlib import contextmanager
import psycopg
from psycopg.rows import dict_row


@contextmanager
def transaction():
    with psycopg.connect(os.environ['DATABASE_URL'], row_factory=dict_row,
                         connect_timeout=5) as conn:
        yield conn
