#!/usr/bin/env python3
"""Give exported xcresult attachments the names the tests asked for.

`xcrun xcresulttool export attachments` writes files under generated names and a
`manifest.json` that maps them back to the `XCTAttachment.name` set in the test. Without
this step the artifact is a folder of UUIDs, which defeats the point of numbering the
screenshots in walk order.

The manifest's exact shape is not something this repo can verify from Linux, so the walk
below is deliberately structural: it recurses through whatever JSON is there looking for
any object that carries both an exported filename and a human-readable name, rather than
assuming a fixed nesting. Anything it cannot interpret is left alone -- the raw export is
still uploaded, so a manifest change degrades the artifact's naming rather than emptying
it.
"""

import json
import os
import re
import shutil
import sys

# Xcode's suggested name is the test's attachment name with an index and a UUID welded on
# -- "01-home" comes back as "01-home_0_3B6CC10F-1E0D-4F8F-BE5E-7B041FEBF74B.png". The
# suffix only disambiguates repeat attachments under one name, which this walk never makes,
# so it is noise in a folder meant to be browsed.
SUFFIX = re.compile(
    r"_\d+_[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"
)

FILENAME_KEYS = ("exportedFileName", "exported_file_name", "fileName", "filename")
NAME_KEYS = (
    "suggestedHumanReadableName",
    "suggested_human_readable_name",
    "humanReadableName",
    "name",
)


def first_value(node, keys):
    for key in keys:
        value = node.get(key)
        if isinstance(value, str) and value:
            return value
    return None


def pairs(node, found):
    """Collect (exported filename, wanted name) from anywhere in the manifest."""
    if isinstance(node, dict):
        exported = first_value(node, FILENAME_KEYS)
        wanted = first_value(node, NAME_KEYS)
        if exported and wanted and exported != wanted:
            found.append((exported, wanted))
        for value in node.values():
            pairs(value, found)
    elif isinstance(node, list):
        for value in node:
            pairs(value, found)
    return found


def main():
    if len(sys.argv) != 2:
        print("usage: rename-screenshots.py <exported-attachments-dir>", file=sys.stderr)
        return 2

    directory = sys.argv[1]
    manifest_path = os.path.join(directory, "manifest.json")
    if not os.path.isfile(manifest_path):
        print(f"no manifest.json in {directory}; leaving exported names as they are")
        return 0

    with open(manifest_path) as handle:
        manifest = json.load(handle)

    renamed = 0
    for exported, wanted in pairs(manifest, []):
        source = os.path.join(directory, exported)
        if not os.path.isfile(source):
            continue

        # The test names attachments "01-home"; keep whatever extension the export chose so
        # the file still opens as an image.
        extension = os.path.splitext(exported)[1] or ".png"
        stem = wanted[: -len(extension)] if wanted.endswith(extension) else wanted
        target_name = SUFFIX.sub("", stem) + extension
        target = os.path.join(directory, target_name.replace("/", "-"))
        if os.path.abspath(source) == os.path.abspath(target):
            continue

        shutil.copyfile(source, target)
        os.remove(source)
        renamed += 1

    print(f"renamed {renamed} attachment(s) in {directory}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
