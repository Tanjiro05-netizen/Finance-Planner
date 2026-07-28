#!/usr/bin/env python3
"""Print the useful parts of macOS/iOS .ips crash reports.

A raw .ips is a two-part JSON blob tens of thousands of lines long, which is
useless in a CI log. What actually diagnoses a Swift trap is three things: the
`asi` application-specific info (where Swift writes its fatal-error message),
the exception/termination pair, and a symbolicated backtrace of the faulting
thread. This prints those and drops the rest.

Usage: print-crash-report.py <directory-of-ips-files> [max-frames]
"""

import json
import pathlib
import sys

MAX_FRAMES_DEFAULT = 40


def load(path):
    """An .ips is a one-line JSON header followed by the JSON payload."""
    text = path.read_text(errors="replace")
    newline = text.find("\n")
    if newline == -1:
        return {}, {}
    try:
        return json.loads(text[:newline]), json.loads(text[newline + 1 :])
    except json.JSONDecodeError as error:
        print(f"  (could not parse: {error})")
        return {}, {}


def frame_text(frame, images):
    image = images[frame["imageIndex"]] if 0 <= frame.get("imageIndex", -1) < len(images) else {}
    name = image.get("name", "???")
    symbol = frame.get("symbol")
    if symbol:
        location = f"{symbol} + {frame.get('symbolLocation', 0)}"
    else:
        location = f"{name} + {frame.get('imageOffset', 0)}"
    source = ""
    if frame.get("sourceFile"):
        source = f"  ({frame['sourceFile']}:{frame.get('sourceLine', 0)})"
    return f"    {name}  {location}{source}"


def report(path, max_frames):
    header, body = load(path)
    if not body:
        return

    print(f"=== {path.name}  ({header.get('app_name', '?')} / {header.get('bundleID', '?')}) ===")

    exception = body.get("exception", {})
    print(f"  exception:   {exception.get('type', '?')} / {exception.get('signal', '?')}")
    print(f"  termination: {body.get('termination', {}).get('indicator', '?')}")

    # Swift's fatalError/precondition message lands here. This is the payload.
    for image_name, messages in (body.get("asi") or {}).items():
        for message in messages:
            print(f"  asi[{image_name}]: {message}")
    for message in body.get("asiBacktraces") or []:
        print(f"  asiBacktrace: {message}")

    images = body.get("usedImages", [])
    threads = body.get("threads", [])
    index = body.get("faultingThread", 0)
    if index < len(threads):
        thread = threads[index]
        print(f"  faulting thread {index} ({thread.get('name') or thread.get('queue') or 'unnamed'}):")
        for frame in thread.get("frames", [])[:max_frames]:
            print(frame_text(frame, images))
    print()


def main():
    if len(sys.argv) < 2:
        print("usage: print-crash-report.py <directory> [max-frames]")
        return 0

    directory = pathlib.Path(sys.argv[1])
    max_frames = int(sys.argv[2]) if len(sys.argv) > 2 else MAX_FRAMES_DEFAULT
    reports = sorted(directory.glob("*.ips")) if directory.is_dir() else []
    if not reports:
        print(f"No .ips crash reports under {directory}")
        return 0

    for path in reports:
        report(path, max_frames)
    return 0


if __name__ == "__main__":
    sys.exit(main())
