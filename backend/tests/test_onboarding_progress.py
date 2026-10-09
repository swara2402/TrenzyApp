"""Tests for persisted onboarding-step progress."""

import importlib.util
from pathlib import Path

import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import create_engine, text


def test_preferences_return_onboarding_step(client, auth_headers):
    saved = client.post(
        "/api/persona/preferences",
        headers=auth_headers,
        json={"preferred_categories": ["Upper"], "onboarding_step": 2},
    )
    assert saved.status_code == 200

    response = client.get("/api/persona/preferences", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["preferences"]["onboarding_step"] == 2


def test_onboarding_step_is_bounded(client, auth_headers):
    saved = client.post(
        "/api/persona/preferences",
        headers=auth_headers,
        json={"onboarding_step": 99},
    )
    assert saved.status_code == 200

    response = client.get("/api/persona/preferences", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["preferences"]["onboarding_step"] == 5


@pytest.mark.parametrize("column_already_exists", [False, True])
def test_onboarding_step_migration_backfills_legacy_rows(column_already_exists):
    migration_path = (
        Path(__file__).parents[1]
        / "migrations"
        / "versions"
        / "0021_persist_onboarding_step.py"
    )
    spec = importlib.util.spec_from_file_location(
        "onboarding_step_migration", migration_path
    )
    assert spec is not None and spec.loader is not None
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)

    engine = create_engine("sqlite://")
    extra_column = (
        ", onboarding_step INTEGER NOT NULL DEFAULT 0"
        if column_already_exists
        else ""
    )
    with engine.begin() as connection:
        connection.execute(
            text(
                f"""
                CREATE TABLE user_preferences (
                    user_firebase_uid TEXT PRIMARY KEY,
                    preferred_categories JSON,
                    preferred_styles JSON,
                    budget_max INTEGER,
                    shopping_priorities JSON{extra_column}
                )
                """
            )
        )
        connection.execute(
            text(
                """
                INSERT INTO user_preferences (
                    user_firebase_uid, preferred_categories, preferred_styles,
                    budget_max, shopping_priorities
                ) VALUES
                ('new', NULL, NULL, NULL, NULL),
                ('categories', '[]', NULL, NULL, NULL),
                ('discovery', '[]', '[]', NULL, NULL),
                ('complete', '[]', '[]', 1000, '[]')
                """
            )
        )
        context = MigrationContext.configure(connection)
        with Operations.context(context):
            migration.upgrade()

        progress = dict(
            connection.execute(
                text(
                    "SELECT user_firebase_uid, onboarding_step "
                    "FROM user_preferences"
                )
            ).all()
        )
        assert progress == {
            "new": 1,
            "categories": 2,
            "discovery": 3,
            "complete": 5,
        }
