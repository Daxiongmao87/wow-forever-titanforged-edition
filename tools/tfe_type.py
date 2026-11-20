#!/usr/bin/env python3
"""Type a hidden secret (password) into whatever field currently has focus.

Reads with no echo via getpass, injects through `adb shell input text` with
%XX URL escaping, which survives symbols and digits that the Titan alt layer
cannot deliver inside games. Nothing is written to disk or shell history.

Usage: focus the target field, then run:  python tools/tfe_type.py
Optional second injection of ENTER:      python tools/tfe_type.py --enter
"""
import getpass
import subprocess
import sys
from urllib.parse import quote

secret = getpass.getpass("secret (no echo, nothing stored): ")
if secret:
    subprocess.run(["adb", "shell", "input", "text", quote(secret, safe="")], check=True)
if "--enter" in sys.argv[1:]:
    subprocess.run(["adb", "shell", "input", "keyevent", "66"], check=True)
print("typed")
