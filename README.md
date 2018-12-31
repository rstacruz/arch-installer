<p align='center'>
<br><img src='./docs/images/screencast.gif' width='500'><br>
</p>

<h1 align='center'>
arch-installer
</h1>

<p align='center'>
:construction: Arch Linux installer UI (unofficial)
</p>

<p align='center'>
<img src='https://img.shields.io/badge/build-pending-lightgrey.svg'>
</p>

<br>

## Usage instructions

Boot into the Arch Linux Live environment, and get it online. In the `root@archiso ~ #` prompt, type: _([view source](https://git.io/fhLAB))_

```sh
curl -sL https://git.io/fhLAB | bash
```

A more detailed guide is available here: [**Installation guide**](./docs/install_guide.md)

## Limitations

The installer is best suited for modern desktops. Only GPT disks and UEFI boot are fully-supported. (Legacy MBR setups are okay, too, but you'll have to partition/format/mount it manually.)

## Is it safe?

Yes.

- It won't modify anything until the very last step. Feel free to explore it (even on your live system).

- It won't actually partition disks for you (unless you choose `Full wipe`). If you choose to 'partition now', it will simply print instructions on how to use `cfdisk` to do it yourself.

- It tries to exit when it finds that something may not be in order. It even displays helpful troubleshooting messages whenever possible.

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
