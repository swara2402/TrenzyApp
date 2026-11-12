"""Boundary tests for Trenzy's server-side 16+ age policy."""

from datetime import date

import pytest

from app.age_policy import calculate_age, is_minor, validate_date_of_birth


def test_user_turning_16_today_is_eligible():
    today = date(2026, 11, 12)
    dob = date(2010, 11, 12)
    assert calculate_age(dob, today=today) == 16
    assert validate_date_of_birth(dob, today=today) == 16
    assert is_minor(dob, today=today) is True


def test_user_who_turns_16_tomorrow_is_not_eligible():
    with pytest.raises(ValueError, match="16 and older"):
        validate_date_of_birth(date(2010, 11, 13), today=date(2026, 11, 12))


def test_future_date_of_birth_is_rejected():
    with pytest.raises(ValueError, match="future"):
        validate_date_of_birth(date(2027, 1, 1), today=date(2026, 11, 12))


def test_adult_is_not_classified_as_minor():
    dob = date(2000, 1, 1)
    assert validate_date_of_birth(dob, today=date(2026, 11, 12)) == 26
    assert is_minor(dob, today=date(2026, 11, 12)) is False
