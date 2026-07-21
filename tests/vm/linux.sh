#!/bin/sh
# SPDX-License-Identifier: BSD-3-Clause
#
# Linux VM scenario for devbind -- executed as root inside the guest by the
# fbsdvm harness (--os linux). Requires python3, pciutils, lsof and an
# emulated NVMe device (qemu -device nvme), which Linux exposes as nvme0
# with namespace /dev/nvme0n1.

set -u

fail=0
note() { echo; echo "== $*"; }
ok()   { echo "ok: $*"; }
bad()  { echo "FAIL: $*"; fail=$((fail + 1)); }

DEVBIND="python3 src/devbind/devbind.py"

note "environment"
uname -sr
lspci -Dn | grep "0108" || { echo "no emulated NVMe controller found"; exit 1; }

# uio_pci_generic may be absent from cloud kernels; bind steps adapt below
if modprobe uio_pci_generic 2>/dev/null; then
    HAVE_UIO=1
else
    HAVE_UIO=0
    echo "note: uio_pci_generic not available in this kernel; skipping its bind test"
fi

note "--version / --list"
$DEVBIND --version || bad "--version"
$DEVBIND --list >/tmp/list.out 2>&1 || bad "--list rc"
grep -q "driver: 'nvme'" /tmp/list.out && ok "sysfs probe reports driver nvme" || bad "driver probe"
BDF=$(sed -n "s/^  bdf: '\(.*\)'/\1/p" /tmp/list.out | head -1)
if [ -n "$BDF" ]; then
    ok "bdf parsed: $BDF"
else
    bad "bdf missing from --list"
    echo "cannot continue without a BDF; aborting"
    exit "$fail"
fi
grep -q "/dev/nvme0n1" /tmp/list.out && ok "namespace handle found" || bad "nvme0n1 handle missing"
grep -q "iommugroup: 'None'" /tmp/list.out && ok "no IOMMU -> iommugroup None" || bad "iommugroup"
if [ "$HAVE_UIO" = 1 ]; then
    grep -q "uio_pci_generic: {'available': True}" /tmp/list.out \
        && ok "uio_pci_generic reported available" || bad "uio availability"
fi
grep -q "vfio-pci: {'available': False}" /tmp/list.out \
    && ok "vfio-pci reported unavailable (module not loaded)" || bad "vfio availability"

note "cross-platform --bind is rejected before touching the device"
$DEVBIND --bind nic_uio --device "$BDF" >/tmp/bind-x.out 2>&1
rc=$?
if [ $rc -eq 22 ] && grep -q "not supported on this platform" /tmp/bind-x.out; then
    ok "nic_uio rejected with EINVAL"
else
    bad "nic_uio rejection (rc=$rc)"
fi
[ -e "/sys/bus/pci/devices/$BDF/driver" ] && ok "device still bound after rejection" || bad "device state changed"

note "in-use device is skipped (lsof)"
# exec sleep so $HOLDER is the fd-holding pid itself (a plain `sleep` child
# would inherit fd 3 and survive the kill)
sh -c 'exec 3</dev/nvme0n1; exec sleep 30' &
HOLDER=$!
sleep 1
$DEVBIND --unbind --device "$BDF" >/tmp/unbind-busy.out 2>&1
grep -q "Skipping unbind" /tmp/unbind-busy.out && ok "unbind skipped while nvme0n1 is open" || bad "in-use skip"
[ -e "/sys/bus/pci/devices/$BDF/driver" ] && ok "device still bound while busy" || bad "busy device was unbound"
kill $HOLDER 2>/dev/null
wait $HOLDER 2>/dev/null

note "unbind via sysfs"
$DEVBIND --unbind --device "$BDF" >/tmp/unbind.out 2>&1 || bad "unbind rc"
[ ! -e "/sys/bus/pci/devices/$BDF/driver" ] && ok "sysfs driver link gone" || bad "still bound"
$DEVBIND --list --device "$BDF" >/tmp/list-unbound.out 2>&1
grep -q "driver: 'None'" /tmp/list-unbound.out && ok "--list reports no driver" || bad "--list driver state"

if [ "$HAVE_UIO" = 1 ]; then
    note "bind to uio_pci_generic (driver_override + setpci)"
    $DEVBIND --bind uio_pci_generic --device "$BDF" >/tmp/bind-uio.out 2>&1 || bad "bind rc"
    case "$(readlink "/sys/bus/pci/devices/$BDF/driver")" in
        *uio_pci_generic) ok "bound to uio_pci_generic" ;;
        *) bad "not bound to uio_pci_generic" ;;
    esac
    CMDREG=$(setpci -s "$BDF" COMMAND)
    case "$CMDREG" in
        *6) ok "COMMAND register memory+busmaster set ($CMDREG)" ;;
        *) bad "COMMAND register not set ($CMDREG)" ;;
    esac
fi

note "bind back to nvme"
$DEVBIND --bind nvme --device "$BDF" >/tmp/bind.out 2>&1 || bad "bind rc"
case "$(readlink "/sys/bus/pci/devices/$BDF/driver")" in
    *nvme) ok "bound back to nvme" ;;
    *) bad "not bound to nvme" ;;
esac
# The controller comes back as a new instance (nvmeN is not reused); assert
# through devbind itself that the new namespace handles are collected
for i in 1 2 3 4 5; do
    [ -n "$(ls "/sys/bus/pci/devices/$BDF/nvme/" 2>/dev/null)" ] && break
    sleep 1
done
$DEVBIND --list --device "$BDF" >/tmp/list-rebound.out 2>&1
grep -q "/dev/nvme" /tmp/list-rebound.out && ok "namespace handles back after rebind" || bad "handles after rebind"

note "result"
if [ "$fail" -eq 0 ]; then
    echo "ALL CHECKS PASSED"
else
    echo "$fail CHECK(S) FAILED"
fi
exit "$fail"
