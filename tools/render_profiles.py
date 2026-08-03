#!/usr/bin/env python3
"""Render the six standalone VPS tuning scripts from one reviewed template."""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "tools" / "profile-template.sh.in"

PROFILES = {
    "debian12-1c512m-vps-tuning.sh": {
        "DEBIAN_VERSION": "12",
        "DEBIAN_CODENAME": "bookworm",
        "PROFILE_ID": "debian12-1c512m",
        "PROFILE_LABEL": "Debian 12 / 1 vCPU / 512 MiB",
        "CPU_MIN": "1",
        "CPU_MAX": "1",
        "RAM_MIN_MIB": "384",
        "RAM_MAX_MIB": "767",
        "BUF_MAX_LIMIT": "16777216",
        "BUFFER_TARGET_NUMERATOR": "1",
        "BUFFER_TARGET_DENOMINATOR": "1",
        "SWAP_MAX_MIB": "2048",
        "SWAP_RESERVE_MIB": "256",
        "JOURNAL_SYSTEM_MAX_USE": "64M",
        "JOURNAL_RUNTIME_MAX_USE": "16M",
        "JOURNAL_KEEP_FREE": "256M",
    },
    "debian12-1c1g-vps-tuning.sh": {
        "DEBIAN_VERSION": "12",
        "DEBIAN_CODENAME": "bookworm",
        "PROFILE_ID": "debian12-1c1g",
        "PROFILE_LABEL": "Debian 12 / 1 vCPU / 1 GiB",
        "CPU_MIN": "1",
        "CPU_MAX": "1",
        "RAM_MIN_MIB": "768",
        "RAM_MAX_MIB": "1535",
        "BUF_MAX_LIMIT": "33554432",
        "BUFFER_TARGET_NUMERATOR": "5",
        "BUFFER_TARGET_DENOMINATOR": "4",
        "SWAP_MAX_MIB": "2048",
        "SWAP_RESERVE_MIB": "512",
        "JOURNAL_SYSTEM_MAX_USE": "128M",
        "JOURNAL_RUNTIME_MAX_USE": "32M",
        "JOURNAL_KEEP_FREE": "512M",
    },
    "debian12-1c2g-vps-tuning.sh": {
        "DEBIAN_VERSION": "12",
        "DEBIAN_CODENAME": "bookworm",
        "PROFILE_ID": "debian12-1c2g",
        "PROFILE_LABEL": "Debian 12 / 1–2 vCPU / 2 GiB",
        "CPU_MIN": "1",
        "CPU_MAX": "2",
        "RAM_MIN_MIB": "1536",
        "RAM_MAX_MIB": "3072",
        "BUF_MAX_LIMIT": "67108864",
        "BUFFER_TARGET_NUMERATOR": "3",
        "BUFFER_TARGET_DENOMINATOR": "2",
        "SWAP_MAX_MIB": "4096",
        "SWAP_RESERVE_MIB": "1024",
        "JOURNAL_SYSTEM_MAX_USE": "128M",
        "JOURNAL_RUNTIME_MAX_USE": "64M",
        "JOURNAL_KEEP_FREE": "1G",
    },
    "debian13-1c512m-vps-tuning.sh": {
        "DEBIAN_VERSION": "13",
        "DEBIAN_CODENAME": "trixie",
        "PROFILE_ID": "debian13-1c512m",
        "PROFILE_LABEL": "Debian 13 / 1 vCPU / 512 MiB",
        "CPU_MIN": "1",
        "CPU_MAX": "1",
        "RAM_MIN_MIB": "384",
        "RAM_MAX_MIB": "767",
        "BUF_MAX_LIMIT": "16777216",
        "BUFFER_TARGET_NUMERATOR": "1",
        "BUFFER_TARGET_DENOMINATOR": "1",
        "SWAP_MAX_MIB": "2048",
        "SWAP_RESERVE_MIB": "256",
        "JOURNAL_SYSTEM_MAX_USE": "64M",
        "JOURNAL_RUNTIME_MAX_USE": "16M",
        "JOURNAL_KEEP_FREE": "256M",
    },
    "debian13-1c1g-vps-tuning.sh": {
        "DEBIAN_VERSION": "13",
        "DEBIAN_CODENAME": "trixie",
        "PROFILE_ID": "debian13-1c1g",
        "PROFILE_LABEL": "Debian 13 / 1 vCPU / 1 GiB",
        "CPU_MIN": "1",
        "CPU_MAX": "1",
        "RAM_MIN_MIB": "768",
        "RAM_MAX_MIB": "1535",
        "BUF_MAX_LIMIT": "33554432",
        "BUFFER_TARGET_NUMERATOR": "5",
        "BUFFER_TARGET_DENOMINATOR": "4",
        "SWAP_MAX_MIB": "2048",
        "SWAP_RESERVE_MIB": "512",
        "JOURNAL_SYSTEM_MAX_USE": "128M",
        "JOURNAL_RUNTIME_MAX_USE": "32M",
        "JOURNAL_KEEP_FREE": "512M",
    },
    "debian13-1c2g-vps-tuning.sh": {
        "DEBIAN_VERSION": "13",
        "DEBIAN_CODENAME": "trixie",
        "PROFILE_ID": "debian13-1c2g",
        "PROFILE_LABEL": "Debian 13 / 1–2 vCPU / 2 GiB",
        "CPU_MIN": "1",
        "CPU_MAX": "2",
        "RAM_MIN_MIB": "1536",
        "RAM_MAX_MIB": "3072",
        "BUF_MAX_LIMIT": "67108864",
        "BUFFER_TARGET_NUMERATOR": "3",
        "BUFFER_TARGET_DENOMINATOR": "2",
        "SWAP_MAX_MIB": "4096",
        "SWAP_RESERVE_MIB": "1024",
        "JOURNAL_SYSTEM_MAX_USE": "128M",
        "JOURNAL_RUNTIME_MAX_USE": "64M",
        "JOURNAL_KEEP_FREE": "1G",
    },
}


def render(template: str, values: dict[str, str]) -> str:
    result = template
    for key, value in values.items():
        result = result.replace(f"@{key}@", value)
    unresolved = re.findall(r"@[A-Z][A-Z0-9_]*@", result)
    if unresolved:
        raise RuntimeError(
            f"unresolved template placeholder(s): {', '.join(sorted(set(unresolved)))}"
        )
    return result.replace("\r\n", "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if generated files differ")
    args = parser.parse_args()
    template = TEMPLATE.read_text(encoding="utf-8")
    failed = False
    for name, values in PROFILES.items():
        target = ROOT / name
        expected = render(template, values)
        current = target.read_text(encoding="utf-8") if target.exists() else None
        if args.check:
            if current != expected:
                print(f"out of date: {name}", file=sys.stderr)
                failed = True
        else:
            target.write_text(expected, encoding="utf-8", newline="\n")
            print(f"rendered: {name}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
