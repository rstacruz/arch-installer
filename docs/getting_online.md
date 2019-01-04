# Connecting to the Internet

There are 3 ways you can get online:

- [Via wifi](#via-wifi)
- [Via ethernet](#via-ethernet)
- [Via Android tethering](#via-android-tethering)

## Via wifi

<a href='./images/wifi-menu.gif'><img width='420' src='./images/wifi-menu.gif'></a>

All you need to do is type `wifi-menu`.

```
root@archiso ~ # wifi-menu
Scanning for networks...
```

### If that didn't work

Running `iw dev` will show all the wireless networking devices found by Linux. See if yours is there.

```bash
# Find interface names:
iw dev
```

If you don't see your wifi device above, then you may need some drivers that don't come pre-installed in the Arch Linux live environment. In this case, try connecting via Ethernet or Android tethering instead.

## Via Ethernet

If you booted Arch Linux with an Ethernet cable on, it should already auto-connect. If not, you can run:

```sh
dhcpcd
```

## Via Android phone

If you have an Android phone, this is the easiest way to go online. Connect your phone to your computer, then **Settings** → **Tethering & Mobile Hotspot** → **USB Tethering** (it's disabled unless your phone is connected). Then connect to it using `dhcpcd`.

```sh
# Find interface names:
ip addr
```

```sh
# Then enable it:
dhcpcd enp0s26f7u3u3
#      ^^^^^^^^^^^^^
#      replace this with the
#      actual interface name
```

## Check if you're online

Run `ping 8.8.8.8` to check if you're finally online.

<img width='320' src='./images/online-ping.gif'>

## References

- [Arch Install over Wifi](https://bbs.archlinux.org/viewtopic.php?id=213577) _(bbs.archlinux.org)_
- [Android tethering](https://wiki.archlinux.org/index.php/Android_tethering) _(wiki.archlinux.org)_
- [Network configuration](https://wiki.archlinux.org/index.php/Network_configuration) _(wiki.archlinux.org)_
- [Arch ISO supports Android Tethering](https://www.reddit.com/r/archlinux/comments/2v8k8o/the_arch_iso_supports_android_usb_tethering/) _(reddit.com)_
