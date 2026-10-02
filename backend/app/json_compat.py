"""Portable "JSON array contains element" predicate.

Works on PostgreSQL (where the ``tags``-style columns are JSONB) and on the
SQLite development fallback (where JSON values are stored as TEXT).

Naively using ``column.contains(value)`` renders ``column LIKE '%value%'``.
On PostgreSQL that fails with ``operator does not exist: json ~~ text``
because JSONB has no text ``LIKE`` operator — every tag/keyword-filtered query
5xx'd. Casting the column to text first makes the substring predicate valid on
both databases while keeping the exact-element semantics safe against LIKE
wildcards (which are escaped away).
"""

import json

from sqlalchemy import cast, String


def _escape_like(value: str) -> str:
    """Escape LIKE wildcards so input text can't inject ``%`` or ``_``."""
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def json_array_contains(column, element):
    """Build a predicate: the JSON array in ``column`` contains ``element``."""
    serialized = json.dumps(element)
    pattern = f"%{_escape_like(serialized)}%"
    return cast(column, String).like(pattern, escape="\\")