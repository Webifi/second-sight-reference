"""Download every source document listed in sources/manifest.json and verify it.

The scans, ROM dumps and third-party files this reference is built on are not stored in
the repository. This script fetches each one from the address it was taken from, saves it
under sources/<local path>, and checks its SHA-256 against the manifest.

Usage:
    python tools/fetch_sources.py
        fetch everything that has a checksum

    python tools/fetch_sources.py ROM
        fetch only entries whose id contains "ROM"

    python tools/fetch_sources.py --list
        print the manifest without downloading

Notes:
- Some hosts have expired TLS certificates. If an HTTPS download fails, the script
  retries the same path over plain HTTP. The SHA-256 check is what proves the file.
- Entries of kind "link" are references only and are never downloaded.
"""

import hashlib
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "sources" / "manifest.json"


def download(url):
    """Return the body at url, retrying over HTTP when HTTPS fails."""
    request = urllib.request.Request(url, headers={"User-Agent": "second-sight-reference/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            return response.read()
    except (urllib.error.URLError, OSError):
        if not url.startswith("https://"):
            raise
        fallback = "http://" + url[len("https://"):]
        request = urllib.request.Request(fallback, headers={"User-Agent": "second-sight-reference/1.0"})
        with urllib.request.urlopen(request, timeout=180) as response:
            return response.read()


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--list" in sys.argv:
        for entry in manifest["entries"]:
            print(f"{entry['kind']:9} {entry['id']}\n          {entry['url']}\n          {entry['title']}")
        return 0
    failures = 0
    for entry in manifest["entries"]:
        if "sha256" not in entry:
            continue
        if args and not any(a.lower() in entry["id"].lower() for a in args):
            continue
        target = ROOT / "sources" / entry["local"]
        if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == entry["sha256"]:
            print("ok (cached)  " + entry["local"])
            continue
        try:
            data = download(entry["url"])
        except Exception as error:  # report and keep going; one dead host should not stop the rest
            print(f"FAILED       {entry['local']}: {error}")
            failures += 1
            continue
        digest = hashlib.sha256(data).hexdigest()
        if digest != entry["sha256"]:
            print(f"HASH MISMATCH {entry['local']}: got {digest}, expected {entry['sha256']}")
            failures += 1
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        print("ok           " + entry["local"])
    if failures:
        print(f"{failures} file(s) failed; the rest are in {ROOT / 'sources'}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
