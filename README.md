# Streambox

The VR Audio Proxy in a box.


## Dependencies

All instructions are based on `raspbian jessie lite`.

* Download zip from https://www.raspberrypi.org/downloads/raspbian/
* unzip
* dd resulting img to sdcard

E.g.

    dd bs=4M if=2016-03-18-raspbian-jessie.img of=/dev/mmcblk0

This will take a while. (It takes almost 5 minutes on my machine.) You
can use `time` to find out how long exactly. Or append `&& aplay
<some-wav>` to get an alert when done.


## Intial Setup on a clean raspbian image

Find the PI in you local network. Connect a display the pi will print
it's ip address during boot. Otherwise `nmap` or `nc` are helpfull to
poke around.

Ssh into the pi with forward agent `-A`.

Username `pi`, password `raspberry`.


### Step 1: Become root

    sudo -i


### Step 2: Main Setup

```
apt-get update
apt-get -y install git
( cd /home/pi &&
  git clone git@gitlab.com:voicerepublic/streambox.git )

mkdir -p /etc/systemd/system/default.target.wants
ln -s /home/pi/streambox/streambox.service \
      /etc/systemd/system/default.target.wants
mv /etc/systemd/system/getty.target.wants/getty@tty1.service \
   /etc/systemd/system/getty.target.wants/getty@tty2.service

mkdir -p /root/.ssh
ssh-keyscan gitlab.com >> ~/.ssh/known_hosts
```


### Step 3: Adjust boot params

To

    /boot/cmdline.txt

add

    quiet consoleblank=0


### Step 4: Type & Subtype

The type of the box is allways 'Streambox'.

The subtype is stored in `/home/pi/subtype`.

If you make a change to the box setup, which is not covered by the git
repo, please update the subtype file.

    echo -n "v0.3prototype" > /home/pi/subtype


### Step 5: raspi-config

* use `sudo raspi-config` to
  * expand file system
  * change the user password to `aeg9ethoh0thioji`
  * set timezone to berlin (for now)


### Step 6: Reboot

If the previous step didn't cause a reboot, reboot!

    reboot


## Helpful commands

### Remote control

Send commands to box from rails console, e.g.

    device = '/device/000000008ff66473'
    Faye.publish_to device, event: 'eval', eval: '21*2'
    Faye.publish_to device, event: 'exit'
    Faye.publish_to device, event: 'reboot'
    Faye.publish_to device, event: 'shutdown'
    Faye.publish_to device, event: 'start_stream', icecast: {...}
    Faye.publish_to device, event: 'stop_stream'


### Force Restart (kill running ruby processes)

    sudo killall ruby


### Force Update (if auto update is broken)

    (cd streambox && git pull) && sudo reboot


## Duplication

### Create an image

    dd bs=4M if=/dev/mmcblk0 of=streambox_v0-3prototype.img


### Write that image to a new card

    dd bs=4M of=/dev/mmcblk0 if=streambox_v0-3prototype.img


## Once and only once, I had to do this...

Create a deploy key

    ssh-keygen -t rsa -C boxed key

Add the public key to this repo on GitLab.

Check both keys (public and private) into this repo.


## TODO

* for production boxes make commands in scripts silent
* set the timezone of organization/venue
  * https://www.raspberrypi.org/forums/viewtopic.php?t=4977&f=5
