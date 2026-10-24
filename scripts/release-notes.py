#!/usr/bin/env python3
"""Writes Markdown release notes for a tag from the commits since the previous tag.

Usage: scripts/release-notes.py <tag> [--repo owner/name] [--unsigned]

Each commit becomes a bullet (its subject) with the bullet points or first
paragraph of its message underneath. Release commits, merges and trailers are left out.
"""
import argparse
import re
import subprocess


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def previous_tag(tag):
    try:
        return git("describe", "--tags", "--abbrev=0", f"{tag}^").strip() or None
    except subprocess.CalledProcessError:
        return None


TRAILER = re.compile(r"^(Co-Authored-By|Signed-off-by|Reviewed-by):", re.IGNORECASE)
SKIP = re.compile(r"^(Release v?\d|Merge |Initial commit$)")


def details(body):
    """Bullet points from a commit body, or its first paragraph as one line."""
    lines = [l.rstrip() for l in body.splitlines() if not TRAILER.match(l.strip())]
    bullets, current = [], None
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("- "):
            current = stripped[2:]
            bullets.append(current)
        elif stripped and current is not None and line.startswith(" "):
            bullets[-1] += " " + stripped
        elif not stripped:
            current = None
    if bullets:
        return bullets
    paragraph = []
    for line in lines:
        if not line.strip():
            if paragraph:
                break
            continue
        paragraph.append(line.strip())
    return [" ".join(paragraph)] if paragraph else []


def notes(tag, repo, unsigned):
    prev = previous_tag(tag)
    rng = f"{prev}..{tag}" if prev else tag
    raw = git("log", "--no-merges", "--format=%s%x1f%b%x1e", rng)
    version = re.sub(r"^v", "", tag)

    out = ["## What's new", ""]
    entries = 0
    for record in raw.split("\x1e"):
        if not record.strip():
            continue
        subject, _, body = record.strip("\n").partition("\x1f")
        if SKIP.match(subject):
            continue
        entries += 1
        out.append(f"- **{subject}**")
        out.extend(f"  - {item}" for item in details(body))
    if entries == 0:
        out.append("- Maintenance release.")

    out += ["", "## Install", "",
            f"Download **Lanyard-{version}.dmg** below, open it, and drag Lanyard into Applications. "
            "Requires macOS 13 or later."]
    if unsigned:
        out += ["", "This build isn't notarized yet: on first launch, open it from "
                "System Settings → Privacy & Security → Open Anyway."]
    if repo and prev:
        out += ["", f"**Full changelog:** https://github.com/{repo}/compare/{prev}...{tag}"]
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("tag")
    parser.add_argument("--repo")
    parser.add_argument("--unsigned", action="store_true")
    args = parser.parse_args()
    print(notes(args.tag, args.repo, args.unsigned), end="")
