#!/usr/bin/env python3
"""Scan the repository for accidentally committed secrets.

Runs on:
- every file Git tracks (``git ls-files``)
- every file Git is aware of as untracked (so keys dropped into the working
  tree are caught before they get staged)

Fails (exit code 1) if any private key or high-value credential is found, so
it is safe to run from a pre-commit hook or CI.

Placeholder values like ``REPLACE_WITH_YOUR_PRIVATE_KEY`` are ignored on
purpose — they are template files, not leaked secrets.
"""

import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# High-value patterns that indicate a real private key or credential.
PATTERNS = [
    (r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED |)PRIVATE KEY-----",
     "PEM/DER private key block"),
    (r'"private_key"\s*:\s*"-----BEGIN', "Firebase/Google service account private key"),
    (r"AKIA[0-9A-Z]{16}", "AWS access key id"),
    (r"(?i)firebase-adminsdk-[a-z0-9-]+\.json", "Firebase Admin SDK key filename"),
    (r"(?i)trenzy2400-firebase-adminsdk-[a-z0-9-]+\.json", "Project-specific Firebase Admin SDK key filename"),
    (r"(?i)-----BEGIN PGP PRIVATE KEY BLOCK-----", "PGP private key block"),
    (r"xox[baprs]-[A-Za-z0-9-]{10,}", "Slack API token"),
    (r"ghp_[A-Za-z0-9]{36,}", "GitHub personal access token"),
    (r"sk-[A-Za-z0-9]{20,}", "OpenAI-style secret key"),
]

# Compound checks: both markers must appear in the same file to count, which
# avoids flagging documentation examples or test fixtures that merely mention
# the words "service_account" without an actual private key.
COMPOUND_CHECKS = [
    ("Google service account JSON with private key",
     r'"type"\s*:\s*"service_account"',
     r'"private_key"\s*:'),
]

# Files that legitimately contain placeholder/example credentials.
PLACEHOLDER_MARKERS = [
    "REPLACE_WITH_YOUR_PRIVATE_KEY",
    "REPLACE_WITH_YOUR_PROJECT_ID",
    "example_service_account",
    "YOUR_PRIVATE_KEY",
    "BEGIN FAKE PRIVATE KEY",
]

# Paths that are never scanned (build artifacts, vendored deps, lockfiles).
SKIP_PREFIXES = (".git/", "build/", ".dart_tool/", ".pub-cache/", "node_modules/")
SKIP_NAMES = {"pubspec.lock", "package-lock.json"}


def _git_files() -> list[str]:
    """Return tracked + untracked files known to Git, including ignored ones.

    Ignored files are scanned too: a service-account key that is accidentally
    dropped into the working tree must fail the scan even if it is gitignored.
    """
    try:
        tracked = subprocess.check_output(
            ["git", "ls-files"], cwd=REPO_ROOT, text=True, stderr=subprocess.DEVNULL
        ).splitlines()
        untracked = subprocess.check_output(
            ["git", "ls-files", "--others"],
            cwd=REPO_ROOT, text=True, stderr=subprocess.DEVNULL
        ).splitlines()
    except (subprocess.CalledProcessError, FileNotFoundError):
        files = []
        for p in REPO_ROOT.rglob("*"):
            if p.is_file():
                files.append(str(p.relative_to(REPO_ROOT)))
        return sorted(files)
    return sorted(set(tracked) | set(untracked))


def _is_placeholder(content: str) -> bool:
    return any(marker in content for marker in PLACEHOLDER_MARKERS)


def main() -> int:
    findings: list[str] = []
    for rel in _git_files():
        if rel.startswith(SKIP_PREFIXES) or rel.split("/")[-1] in SKIP_NAMES:
            continue
        path = REPO_ROOT / rel
        if not path.is_file():
            continue
        try:
            content = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if _is_placeholder(content):
            continue
        for regex, label in PATTERNS:
            if re.search(regex, content):
                findings.append(f"{rel}: {label}")
        for label, marker_a, marker_b in COMPOUND_CHECKS:
            if re.search(marker_a, content) and re.search(marker_b, content):
                findings.append(f"{rel}: {label}")

    if findings:
        print("SECRET SCAN FAILED — potential credential leak detected:", file=sys.stderr)
        for f in findings:
            print(f"  - {f}", file=sys.stderr)
        print(
            "\nIf this is a real key, revoke it immediately and never commit it. "
            "Load credentials from environment variables or a mounted secret.",
            file=sys.stderr,
        )
        return 1

    print("Secret scan passed: no private keys or high-value credentials found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())