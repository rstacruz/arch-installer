# Connecting via wifi

<a href='./images/wifi-menu.gif'><img width='420' src='./images/wifi-menu.gif'></a>

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

## Check if you're online

Run `ping 8.8.8.8` to check if you're finally online.

<img width='320' src='./images/online-ping.gif'>

## References

- <https://bbs.archlinux.org/viewtopic.php?id=213577>
