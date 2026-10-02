"""Trenzy ML training and evaluation package.

Entry points:
- ``python -m ml.train_all``        — train all models, register versions
- ``python -m ml.evaluate_all``     — evaluate all models vs rule-based baseline
- ``python -m ml.promote_model``    — promote a candidate if it beats production

The package runs against either PostgreSQL (production) or SQLite
(``TRENZY_TEST_DB=1`` local/demo) using the same ``app.db`` session factory.
"""

__version__ = "0.1.0"