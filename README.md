# Streambox

The VR Audio Proxy in a box.

## Dependencies

All instructions are based on `raspbian jessie - minimal`.

## Installation

Ssh into the pi.

```
git clone git@gitlab.com:voicerepublic/streambox.git
cd streambox
./setup.sh

```

### systemd config

Still on the pi.

```
sudo -i
mkdir -p /etc/systemd/system/default.target.wants
ln -s /home/pi/streambox/streambox.service /etc/systemd/system/default.target.wants

```

Reboot.

### Create a deployment key

Sdcard mounted on another device.


```
mkdir /media/859cf567-e7d3-4fa7-82b8-cb835cd272c6/home/pi/.ssh
ssh-keygen -t rsa -C boxed key -f /media/859cf567-e7d3-4fa7-82b8-cb835cd272c6/home/pi/.ssh/id_rsa
```

Add the public key to this repo on GitLab.

### prefill known hosts

As root on pi

    ssh-keyscan gitlab.com >> ~/.ssh/known_hosts

### adjust boot params

To

    /boot/cmdline.txt

add

    quiet consoleblank=0

### expand file system

TODO

### Update (if auto update is broken)

    (cd streambox && git pull) && sudo reboot
