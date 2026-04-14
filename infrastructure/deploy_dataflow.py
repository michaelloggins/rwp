"""Deploy an ADF mapping data flow via the REST PUT API.

Strips `//` comment lines from scriptLines before deploy, because ADF
silently compiles an empty DSL (0 rows, activity still reports Succeeded)
when comments are present. See MEMORY.md.

Usage:
    python infrastructure/deploy_dataflow.py DF_RWP_Transform

Requires an authenticated Azure CLI session (`az login`) with
Contributor on the target Data Factory.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

SUBSCRIPTION = "8d360715-dc0c-4ec3-b879-9e2d1213b76d"
RESOURCE_GROUP = "mvd-core-rg"
FACTORY = "adf-mvd-cus-001"
API_VERSION = "2018-06-01"

ADF_DIR = Path(__file__).resolve().parent.parent / "adf"


def strip_comments(doc: dict) -> tuple[dict, int]:
    """Remove `//`-prefixed scriptLines. Returns (new_doc, removed_count)."""
    lines = doc["properties"]["typeProperties"]["scriptLines"]
    cleaned = [l for l in lines if not re.match(r"^\s*//", l)]
    doc["properties"]["typeProperties"]["scriptLines"] = cleaned
    return doc, len(lines) - len(cleaned)


def deploy(name: str) -> None:
    source = ADF_DIR / f"{name}.json"
    if not source.exists():
        sys.exit(f"ERROR: source file not found: {source}")

    with source.open() as f:
        doc = json.load(f)

    doc, removed = strip_comments(doc)
    print(f"Stripped {removed} comment lines from {name}")

    # Write a temp file that az rest can consume via @file syntax
    tmp = source.with_suffix(".deploy.tmp.json")
    with tmp.open("w") as f:
        json.dump(doc, f, indent=4)

    url = (
        f"https://management.azure.com/subscriptions/{SUBSCRIPTION}"
        f"/resourceGroups/{RESOURCE_GROUP}"
        f"/providers/Microsoft.DataFactory/factories/{FACTORY}"
        f"/dataflows/{name}?api-version={API_VERSION}"
    )
    cmd = [
        "az", "rest",
        "--method", "PUT",
        "--url", url,
        "--body", f"@{tmp.as_posix()}",
        "--query", "{name:name}",
        "-o", "json",
    ]
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print(result.stdout.strip())
    finally:
        tmp.unlink(missing_ok=True)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python deploy_dataflow.py <DataFlowName>")
    deploy(sys.argv[1])
