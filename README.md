# devbind

![devbind: inspect and control PCI device-driver bindings](https://raw.githubusercontent.com/xnvme/devbind/main/assets/banner.svg)

Convenience tool to manage driving PCIe device-driver association.

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
