"""Server-side age verification policy for Trenzy.

The launch contract is 13+ with additional protections for minors. DOB is
stored only on the authenticated user record and is never exposed in public
profile payloads. Minor status is derived from DOB at request time.
"""

from __future__ import annotations

from datetime import date

MINIMUM_AGE = 13
MINOR_MAX_AGE = 17


def calculate_age(date_of_birth: date, today: date | None = None) -> int:
    """Return age in completed years."""
    today = today or date.today()
    if date_of_birth > today:
        raise ValueError("Date of birth cannot be in the future.")
    return today.year - date_of_birth.year - (
        (today.month, today.day) < (date_of_birth.month, date_of_birth.day)
    )


def validate_date_of_birth(date_of_birth: date, today: date | None = None) -> int:
    """Validate the 13+ launch rule and return the calculated age."""
    age = calculate_age(date_of_birth, today=today)
    if age < MINIMUM_AGE:
        raise ValueError("Trenzy is available to users aged 13 and older.")
    return age


def is_minor(date_of_birth: date, today: date | None = None) -> bool:
    """Return whether the verified user is 13–17."""
    age = calculate_age(date_of_birth, today=today)
    return MINIMUM_AGE <= age <= MINOR_MAX_AGE
