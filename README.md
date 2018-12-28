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

Boot into the Arch Linux Live USB, then type this for a graphical installer:

```sh
curl -s https://ricostacruz.com/arch-installer/install.sh | bash
```

## Is it safe?

Yes. \*

- It won't modify anything until the very last step. Feel free to explore it (even on your live system).

- It won't actually partition disks for you. If you choose to 'partition now', it will simply print instructions on how to use `cfdisk` to do it yourself.

`*` = _Mostly yes_

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
