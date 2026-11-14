#!/usr/bin/env python3
"""Prints every failure message in an xcresult bundle, with its test name.

xcodebuild only lists the names of failing Swift Testing tests in its log;
the messages (which expectation failed, with what values) live in the
result bundle. Usage: print-test-failures.py <path.xcresult>
"""
import json
import subprocess
import sys


def walk(node, trail):
    name = node.get("name", "")
    if node.get("nodeType") == "Failure Message":
        print(f"FAIL {' › '.join(trail)}\n     {name}")
    for child in node.get("children", []):
        walk(child, trail + ([name] if node.get("nodeType") in ("Test Case", "Test Suite") else []))


def main():
    raw = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", sys.argv[1]],
        capture_output=True, text=True, check=False,
    )
    if raw.returncode != 0:
        print(raw.stderr)
        return
    for node in json.loads(raw.stdout).get("testNodes", []):
        walk(node, [])


if __name__ == "__main__":
    main()
