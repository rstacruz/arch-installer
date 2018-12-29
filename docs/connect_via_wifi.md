# Connecting via wifi

```bash
# Find interface names:
iw dev
```

If you don't see your wifi device above, then you may need some drivers that don't come pre-installed in the Arch Linux live environment. In this case, try connecting via Ethernet or Android tethering instead.

```bash
wifi-menu -o wlp2s0
#            ^^^^^^
#            replace this with the
#            actual interface name
```

## References

- <https://bbs.archlinux.org/viewtopic.php?id=213577>
