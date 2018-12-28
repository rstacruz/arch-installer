<p align='center'>
<br><img src='./docs/screencast.gif' width='500'><br>
</p>

<h1 align='center'>
arch-installer
</h1>

<p align='center'>
:construction: Rico's automated Arch Linux installer (beta)
</p>

<p align='center'>
<img src='https://img.shields.io/badge/build-pending-lightgrey.svg'>
</p>

<br>

Boot into the Arch Linux Live image, then type this for a graphical installer:

```sh
curl -s https://ricostacruz.com/arch-installer/install.sh | bash
```

## Is it safe?

Yes. \*

- It won't modify anything until the very last step. Feel free to explore it (even on your live system).

- It won't actually partition disks for you. If you choose to 'partition now', it will simply print instructions on how to use `cfdisk` to do it yourself.

`*` = _Mostly yes_

## How do I use it?

- Boot into the Arch Linux Live environment. You can do this by [Downloading Arch Linux][download] and [putting it into a USB][usb]. (You can also do this from a VM, of course.)

- Get online. (Tip: my favorite trick is using an Android phone to do [USB Tethering][android].)

- In the `root@archiso ~ #` prompt, type `curl -s https://ricostacruz.com/arch-installer/install.sh | bash`

[android]: https://www.reddit.com/r/archlinux/comments/2v8k8o/the_arch_iso_supports_android_usb_tethering/
[download]: https://www.archlinux.org/download/
[usb]: https://wiki.archlinux.org/index.php/USB_flash_installation_media

## Thanks

**arch-installer** © 2018+, Rico Sta. Cruz. Released under the [MIT] License.<br>
Authored and maintained by Rico Sta. Cruz with help from contributors ([list][contributors]).

> [ricostacruz.com](http://ricostacruz.com) &nbsp;&middot;&nbsp;
> GitHub [@rstacruz](https://github.com/rstacruz) &nbsp;&middot;&nbsp;
> Twitter [@rstacruz](https://twitter.com/rstacruz)

[![](https://img.shields.io/github/followers/rstacruz.svg?style=social&label=@rstacruz)](https://github.com/rstacruz) &nbsp;
[![](https://img.shields.io/twitter/follow/rstacruz.svg?style=social&label=@rstacruz)](https://twitter.com/rstacruz)

[mit]: http://mit-license.org/
[contributors]: http://github.com/rstacruz/arch-installer/contributors
