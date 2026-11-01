#!/usr/bin/env python3
"""Portable, repository-local Trenzy beta audit.

This tool deliberately reports static checks separately from checks that require
live infrastructure or a device. It never reads a developer-specific absolute
path and never labels unavailable evidence as a passing check.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass
class Check:
    name: str
    status: str
    detail: str


def repository_root() -> Path:
    return Path(__file__).resolve().parent.parent


def run_audit(root: Path) -> list[Check]:
    checks: list[Check] = []

    required_files = [
        "lib/app.dart",
        "lib/router/app_router.dart",
        "lib/services/api/api_client.dart",
        "backend/app/main.py",
        "backend/app/routes/auth.py",
        "backend/app/routes/products.py",
        "backend/app/routes/wardrobe.py",
        "backend/app/routes/uploads.py",
        "backend/app/routes/blends.py",
        "backend/tests",
        "test",
    ]
    missing = [name for name in required_files if not (root / name).exists()]
    checks.append(Check(
        "core_repository_structure",
        "PASS" if not missing else "FAIL",
        "All required app/backend/test paths exist." if not missing
        else "Missing: " + ", ".join(missing),
    ))

    test_dir = root / "test"
    flutter_tests = sorted(test_dir.glob("*_test.dart")) if test_dir.exists() else []
    checks.append(Check(
        "flutter_test_presence",
        "PASS" if flutter_tests else "FAIL",
        f"Found {len(flutter_tests)} Flutter test files."
        if flutter_tests else "No Flutter test files found.",
    ))

    backend_tests = root / "backend" / "tests"
    python_tests = sorted(backend_tests.glob("test_*.py")) if backend_tests.exists() else []
    checks.append(Check(
        "backend_test_presence",
        "PASS" if python_tests else "FAIL",
        f"Found {len(python_tests)} backend test modules."
        if python_tests else "No backend test modules found.",
    ))

    gitignore = root / ".gitignore"
    ignored_env = False
    if gitignore.exists():
        rules = [line.strip() for line in gitignore.read_text(encoding="utf-8").splitlines()]
        ignored_env = any(rule in {".env", ".env.*"} for rule in rules)
    checks.append(Check(
        "environment_secret_ignore",
        "PASS" if ignored_env else "REVIEW",
        ".gitignore contains an .env ignore rule."
        if ignored_env else "Could not confirm an .env ignore rule; review secret handling.",
    ))

    flags = root / "lib" / "services" / "feature_flags.dart"
    if flags.exists():
        source = flags.read_text(encoding="utf-8")
        flag_start = source.find("static const bool paymentsEnabled")
        flag_end = source.find(");", flag_start)
        flag_block = source[flag_start:flag_end + 2] if flag_start >= 0 and flag_end >= 0 else ""
        payments_disabled = "defaultValue: false" in flag_block
        checks.append(Check(
            "beta_payment_feature_flag",
            "PASS" if payments_disabled else "REVIEW",
            "Payment feature flag appears disabled by default."
            if payments_disabled else "Could not statically confirm payments are disabled by default.",
        ))
    else:
        checks.append(Check("beta_payment_feature_flag", "REVIEW", "Feature flag file not found."))

    legacy_root = "/Users/" + "sam/Downloads/" + "trenzy_production"
    stale_references: list[str] = []
    for candidate in [root / "backend" / "audit.py"]:
        if candidate.exists() and legacy_root in candidate.read_text(encoding="utf-8"):
            stale_references.append(candidate.relative_to(root).as_posix())
    checks.append(Check(
        "portable_audit_paths",
        "FAIL" if stale_references else "PASS",
        "No developer-specific absolute paths remain in the audit utility."
        if not stale_references else "Legacy absolute path found in: " + ", ".join(stale_references),
    ))

    checks.extend([
        Check("live_backend_and_database", "NOT_RUN",
              "Requires a configured staging environment and live credentials."),
        Check("android_device_visual_ux", "NOT_RUN",
              "Requires emulator or physical-device interaction; source checks cannot replace it."),
        Check("end_to_end_user_journeys", "NOT_RUN",
              "Requires authenticated test accounts and end-to-end execution."),
    ])
    return checks


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json-out", type=Path, help="Optional path for a JSON report.")
    args = parser.parse_args()

    root = repository_root()
    checks = run_audit(root)
    for item in checks:
        print(f"[{item.status:7}] {item.name}: {item.detail}")

    failures = sum(item.status == "FAIL" for item in checks)
    review = sum(item.status == "REVIEW" for item in checks)
    not_run = sum(item.status == "NOT_RUN" for item in checks)
    report = {
        "scope": "repository_static_checks_only",
        "repository_root": str(root),
        "summary": {
            "passed": sum(item.status == "PASS" for item in checks),
            "failed": failures,
            "review": review,
            "not_run": not_run,
        },
        "checks": [asdict(item) for item in checks],
    }
    if args.json_out:
        output = args.json_out if args.json_out.is_absolute() else root / args.json_out
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"JSON report written to {output}")
    print(f"Summary: {report['summary']}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
