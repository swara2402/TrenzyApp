"""Regression coverage for Trenzy's 16+ minimum age policy."""

from datetime import date

import pytest

from app.age_policy import MINIMUM_AGE, is_minor, validate_date_of_birth


def test_minimum_age_is_sixteen():
    assert MINIMUM_AGE == 16


def test_sixteen_year_old_can_verify_on_birthday():
    assert validate_date_of_birth(date(2010, 11, 11), today=date(2026, 11, 11)) == 16


def test_user_under_sixteen_is_rejected():
    with pytest.raises(ValueError, match="16 and older"):
        validate_date_of_birth(date(2011, 11, 12), today=date(2026, 11, 11))


def test_sixteen_and_seventeen_year_olds_are_marked_as_minors():
    assert is_minor(date(2010, 11, 11), today=date(2026, 11, 11)) is True
    assert is_minor(date(2009, 11, 11), today=date(2026, 11, 11)) is True


def test_eighteen_year_old_is_not_marked_as_minor():
    assert is_minor(date(2008, 11, 11), today=date(2026, 11, 11)) is False
