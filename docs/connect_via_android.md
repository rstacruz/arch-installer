# Connecting via Android phone

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

## References

- [Android tethering](https://wiki.archlinux.org/index.php/Android_tethering) _(wiki.archlinux.org)_
- [Network configuration](https://wiki.archlinux.org/index.php/Network_configuration) _(wiki.archlinux.org)_
- [Arch ISO supports Android Tethering](https://www.reddit.com/r/archlinux/comments/2v8k8o/the_arch_iso_supports_android_usb_tethering/) _(reddit.com)_
