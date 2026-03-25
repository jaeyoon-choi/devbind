# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) Simon Andreas Frimann Lund <os@safl.dk>

import subprocess
import sys


def test_help():
    result = subprocess.run(
        [sys.executable, "-m", "devbind.devbind", "--help"],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert "binding" in result.stdout.lower()


def test_import():
    from devbind import main

    assert callable(main)
