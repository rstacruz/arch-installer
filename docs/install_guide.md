## Installing Arch Linux

Boot into the Arch Linux Live environment, and get it online. In the `root@archiso ~ #` prompt, type:

```sh
curl -sL https://git.io/fhLAB | bash
```

A detailed guide on doing this is below.

## Step-by-step instructions

| Image                                                                                                     | Step                                                                                                                                                                                                                                                       |
| --------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <p align='center'><img width='143' height='127' src='./images/arch-iso.png'></p>                          | **Download Arch Linux** <br> [Download the Arch Linux live environment ISO][download] from the official Arch Linux website.                                                                                                                                |
| <a href='./images/ai-systemd-boot.gif'><img width='420' src='./images/ai-systemd-boot.gif'></a>           | **Boot to it** <br> [Put it into a USB drive][usb], and boot your system to it. (If you're installing into a VM, [here's a guide](./creating_virtualbox_vm.md) using VirtualBox.)                                                                          |
| <a href='./images/virtualbox-08-prompt.gif'><img width='420' src='./images/virtualbox-08-prompt.gif'></a> | **Wait for the prompt** <br> Boot to the installer. It takes a while, but eventually you'll be at the `root @ archiso ~ #` prompt.                                                                                                                         |
| <a href='./images/wifi-menu.gif'><img width='420' src='./images/wifi-menu.gif'></a>                       | **Get online** <br> If you're not online yet, type `wifi-menu` to connect to wifi. (This may or may not work in your system. If it doesn't, try connecting [via ethernet](./connect_via_ethernet.md) or [via Anroid tethering](./connect_via_android.md).) |
| <a href='./images/ai-01-curl-bash.gif'><img width='420' src='./images/ai-01-curl-bash.gif'></a>           | **Type the command** <br> Type the curl command and press _Enter_. This will start the installer.                                                                                                                                                          |
