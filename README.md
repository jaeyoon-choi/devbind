![devbind: inspect and control PCI device-driver binding in Linux](https://raw.githubusercontent.com/xnvme/devbind/main/assets/banner.svg)

# devbind

[![PyPI](https://img.shields.io/pypi/v/devbind.svg)](https://pypi.org/project/devbind/)
[![Python](https://img.shields.io/pypi/pyversions/devbind.svg)](https://pypi.org/project/devbind/)
[![Test](https://github.com/xnvme/devbind/actions/workflows/test.yml/badge.svg)](https://github.com/xnvme/devbind/actions/workflows/test.yml)

Inspect and control PCI device-driver binding in Linux.

## Install

```
pipx install devbind
```

Or standalone (single-file, stdlib only, no pip needed):

```
curl -fsSL https://raw.githubusercontent.com/xnvme/devbind/main/src/devbind/devbind.py \
  -o ~/.local/bin/devbind && chmod +x ~/.local/bin/devbind
```

## Shell completion

```
devbind --print-completion bash > ~/.local/share/bash-completion/completions/devbind
```

Open a new shell (or `source` the file) and tab-completion is live: `devbind --bind <TAB>` lists `nvme vfio-pci vfio-noiommu uio_pci_generic`.

## Related

- [`iommu`](https://github.com/safl/iommu): inspect and configure the IOMMU isolation level in Linux.
- [`hugepages`](https://github.com/xnvme/hugepages): inspect and manage Linux hugepages.
