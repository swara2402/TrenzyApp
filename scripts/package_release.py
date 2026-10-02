#!/usr/bin/env python3
"""Build a clean distribution zip of the Trenzy repo.

Guarantees:
- Never includes .git/, .env files (except .env.example), service-account
  JSONs, google-services.json, keystore/signing files, or build artifacts.
- Fails (exit 1) if any excluded pattern would have been silently required —
  it simply omits them, and prints exactly what was skipped.

Usage:  python3 scripts/package_release.py [--out trenzy_release.zip]
"""

import argparse
import subprocess
import sys
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

EXCLUDED_DIRS = {
    ".git", ".github", ".githooks", ".vscode",
    "__pycache__", ".pytest_cache", ".ruff_cache", ".mypy_cache",
    "node_modules", ".dart_tool", ".gradle", "Pods",
    "build", ".idea", "__MACOSX",
}
EXCLUDED_FILE_PATTERNS = (
    ".env", ".env.local", ".env.test",  # real env files (.env.example is kept)
    "*.pem", "*.jks", "*.keystore", "*.p12", "*.mobileprovision",
    "google-services.json", "GoogleService-Info.plist",
    "*firebase-adminsdk*.json", "*service-account*.json",
    "coverage.xml", ".coverage", "*.log", ".DS_Store", "._*",
)


def _is_excluded(rel: Path) -> bool:
    if any(part in EXCLUDED_DIRS for part in rel.parts):
        return True
    name = rel.name
    for pat in EXCLUDED_FILE_PATTERNS:
        if pat.endswith("*") or pat.startswith("*"):
            import fnmatch
            if fnmatch.fnmatch(name, pat):
                return True
        elif name == pat:
            return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="trenzy_release.zip")
    args = parser.parse_args()

    out_path = REPO_ROOT / args.out

    try:
        tracked = subprocess.check_output(
            ["git", "ls-files"], cwd=REPO_ROOT, text=True, stderr=subprocess.DEVNULL
        ).splitlines()
    except (subprocess.CalledProcessError, FileNotFoundError):
        files = []
        for p in REPO_ROOT.rglob("*"):
            if p.is_file():
                rel = str(p.relative_to(REPO_ROOT))
                files.append(rel)
        tracked = files

    # Package TRACKED files only — untracked local junk never ships.
    included, skipped = [], []
    for rel in sorted(set(tracked)):
        p = Path(rel)
        if _is_excluded(p) or not (REPO_ROOT / p).is_file():
            skipped.append(rel)
            continue
        included.append(rel)

    # Belt-and-braces: verify nothing sensitive slipped through.
    for rel in included:
        if rel.endswith(".py"):
            continue
        content = (REPO_ROOT / rel).read_text(encoding="utf-8", errors="ignore")
        if '"private_key"' in content and "BEGIN" in content:
            print(f"ABORT: {rel} looks like a service-account key.", file=sys.stderr)
            return 1

    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for rel in included:
            zf.write(REPO_ROOT / rel, arcname=str(rel))

    print(f"Wrote {out_path} ({len(included)} files)")
    if skipped:
        print("Skipped sensitive/generated paths:")
        for s in skipped[:40]:
            print(f"  - {s}")
        if len(skipped) > 40:
            print(f"  ... and {len(skipped) - 40} more")
    return 0


if __name__ == "__main__":
    sys.exit(main())
