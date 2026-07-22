# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) Simon Andreas Frimann Lund <os@safl.dk>
"""Unit tests for the Linux backend (runnable on any platform)."""

from types import SimpleNamespace

from devbind import devbind


# Representative `lspci -Dvmmnk` output: an NVMe controller and a
# non-matching ethernet device.
LSPCI_DVMMNK = (
    "Slot:\t0000:01:00.0\n"
    "Class:\t0108\n"
    "Vendor:\t144d\n"
    "Device:\ta808\n"
    "SVendor:\t144d\n"
    "SDevice:\ta801\n"
    "Driver:\tnvme\n"
    "Module:\tnvme\n"
    "\n"
    "Slot:\t0000:03:00.0\n"
    "Class:\t0200\n"
    "Vendor:\t8086\n"
    "Device:\t10d3\n"
    "\n"
)


def test_device_scan_named_device_bypasses_class_filter(monkeypatch):
    monkeypatch.setattr(
        devbind,
        "run",
        lambda cmd: SimpleNamespace(stdout=LSPCI_DVMMNK, stderr="", returncode=0),
    )
    # Avoid touching the real /sys and /dev during probing
    for name in ("probe_handles", "probe_usage", "probe_driver", "probe_iommugroup"):
        monkeypatch.setattr(devbind.Device, name, lambda self: None)

    args = SimpleNamespace(device="0000:03:00.0", classcode=0x0108)
    devices = list(devbind.device_scan(args))

    # The ethernet device is found by BDF even though its class is 0x0200
    assert [d.bdf for d in devices] == ["0000:03:00.0"]
