#!/usr/bin/env python3
"""Build the TitanForged addon zip for the launcher's Add-on installer."""
import os, zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "addon", "TitanForged")
OUT = os.path.join(REPO, "build", "TitanForged.zip")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
    for name in sorted(os.listdir(SRC)):
        z.write(os.path.join(SRC, name), f"TitanForged/{name}")
print(OUT)
