## Installing Arch Linux

## Boot to the live environment

Boot to the Arch Linux live environment. Here's a quick rundown:

1. **Get the official Arch Linux installer** <br>
   [Download the Arch Linux live environment ISO][download], then [put it into a USB drive][usb]. (If you're installing into a VM, [here's a guide](./creating_virtualbox_vm.md) to creating your VM instead.)

   > <img width='143' height='127' src='./images/arch-iso.png'>

2. **Boot to it** <br> Boot into the Arch Linux Live environment. You'll also need to get it online (usually via [wifi](./connect_via_wifi.md), [ethernet](./connect_via_ethernet.md) or [Android](./connect_via_android.md)).

   <a href='./images/virtualbox-08-prompt.gif'><img width='256' src='./images/virtualbox-08-prompt.gif'></a>

3. **Start the arch-installer UI** <br> In the `root@archiso ~ #` prompt, type: `curl -sL https://git.io/fhLAB | bash`

   <a href='./images/ai-01-curl-bash.gif'><img width='256' src='./images/ai-01-curl-bash.gif'></a>

[download]: https://www.archlinux.org/download/
[usb]: https://wiki.archlinux.org/index.php/USB_flash_installation_media

## Step-by-step instructions

| Image                                                                                                     | Step                                                                                                                                                                                                                            |
| --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a href='./images/virtualbox-08-prompt.gif'><img width='420' src='./images/virtualbox-08-prompt.gif'></a> | **Wait for the prompt** <br> Boot to the installer. It takes a while, but eventually you'll be at the `root @ archiso ~ #` prompt.                                                                                              |
| <a href='./images/wifi-menu.gif'><img width='420' src='./images/wifi-menu.gif'></a>                       | **Get online** <br> Type `wifi-menu` to connect to wifi. (This may or may not work in your system. If it doesn't, try connecting [via ethernet](./connect_via_ethernet.md) or [via Anroid tethering](./connect_via_android.md). |
| <a href='./images/online-ping.gif'><img width='420' src='./images/online-ping.gif'></a>                   | **Check if you're online** <br> Type `ping 8.8.8.8` to see if you're online. It should get you some results if you are.                                                                                                         |
| <a href='./images/ai-01-curl-bash.gif'><img width='420' src='./images/ai-01-curl-bash.gif'></a>           | **Type the command** <br> Type the curl command and press _Enter_. This will start the installer.                                                                                                                               |
