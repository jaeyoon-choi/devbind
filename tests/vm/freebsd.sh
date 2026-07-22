#!/bin/sh
# SPDX-License-Identifier: BSD-3-Clause
#
# FreeBSD VM scenario for devbind -- executed as root inside the guest by the
# fbsdvm harness. Requires python3 and an emulated NVMe device (qemu -device
# nvme), which FreeBSD attaches as nvme0 with a CAM disk nda0.

set -u

fail=0
note() { echo; echo "== $*"; }
ok()   { echo "ok: $*"; }
bad()  { echo "FAIL: $*"; fail=$((fail + 1)); }

DEVBIND="python3 src/devbind/devbind.py"

note "environment"
freebsd-version
pciconf -l | grep '^nvme' || { echo "no emulated NVMe controller found"; exit 1; }

SEL=$(pciconf -l | sed -n 's/^nvme[0-9]*@\(pci[0-9]*:[0-9]*:[0-9]*:[0-9]*\):.*/\1/p' | head -1)
echo "selector: $SEL"

note "--version / --list"
$DEVBIND --version || bad "--version"
$DEVBIND --list >/tmp/list.out 2>&1 || bad "--list rc"
grep -q "driver: 'nvme'" /tmp/list.out && ok "scan finds NVMe bound to nvme" || bad "scan driver"
BDF=$(sed -n "s/^  bdf: '\(.*\)'/\1/p" /tmp/list.out | head -1)
if [ -n "$BDF" ]; then
    ok "bdf parsed: $BDF"
else
    bad "bdf missing from --list"
    echo "cannot continue without a BDF; aborting"
    exit "$fail"
fi
grep -q "/dev/nda0" /tmp/list.out && ok "camcontrol maps nvme0 -> nda0 handle" || bad "nda0 handle missing"
grep -q "nic_uio: {'available': False}" /tmp/list.out \
    && ok "nic_uio reported unavailable" || bad "nic_uio availability"

note "pciconf COMMAND-register write syntax (review finding 1)"
pciconf -w -h "$SEL" 0x4 0x6 && ok "fixed form accepted" || bad "fixed form rejected"
if pciconf -w -h -s "$SEL" 0x4 0x6 2>/dev/null; then
    bad "old -s form unexpectedly accepted"
else
    ok "old -s form rejected (the bug was real)"
fi

note "cross-platform --bind is rejected before touching the device"
$DEVBIND --bind vfio-pci --device "$BDF" >/tmp/bind-x.out 2>&1
rc=$?
if [ $rc -eq 22 ] && grep -q "not supported on this platform" /tmp/bind-x.out; then
    ok "vfio-pci rejected with EINVAL"
else
    bad "vfio-pci rejection (rc=$rc)"
fi
pciconf -l | grep -q "^nvme[0-9]*@$SEL:" && ok "device still bound after rejection" || bad "device state changed"

note "in-use device is skipped (fstat via nda0)"
# exec sleep so $HOLDER is the fd-holding pid itself (a plain `sleep` child
# would inherit fd 3 and survive the kill)
sh -c 'exec 3</dev/nda0; exec sleep 30' &
HOLDER=$!
sleep 1
$DEVBIND --unbind --device "$BDF" >/tmp/unbind-busy.out 2>&1
grep -q "Skipping unbind" /tmp/unbind-busy.out && ok "unbind skipped while nda0 is open" || bad "in-use skip"
pciconf -l | grep -q "^nvme[0-9]*@$SEL:" && ok "device still bound while busy" || bad "busy device was detached"
kill $HOLDER 2>/dev/null
wait $HOLDER 2>/dev/null

note "unbind detaches via devctl"
$DEVBIND --unbind --device "$BDF" >/tmp/unbind.out 2>&1 || bad "unbind rc"
pciconf -l | grep -q "^none[0-9]*@$SEL:" && ok "device detached (none@)" || bad "still shows a driver"
$DEVBIND --list --device "$BDF" >/tmp/list-unbound.out 2>&1
grep -q "driver: 'None'" /tmp/list-unbound.out && ok "--list reports no driver" || bad "--list driver state"

note "bind back to nvme via devctl"
$DEVBIND --bind nvme --device "$BDF" >/tmp/bind.out 2>&1 || bad "bind rc"
pciconf -l | grep -q "^nvme[0-9]*@$SEL:" && ok "device reattached to nvme" || bad "reattach"
for i in 1 2 3 4 5; do
    camcontrol devlist 2>/dev/null | grep -q nda && break
    sleep 1
done
camcontrol devlist 2>/dev/null | grep -q nda && ok "nda disk back after rebind" || bad "nda after rebind"

note "result"
if [ "$fail" -eq 0 ]; then
    echo "ALL CHECKS PASSED"
else
    echo "$fail CHECK(S) FAILED"
fi
exit "$fail"
