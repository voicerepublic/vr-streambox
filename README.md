# Streambox

The VR Audio Proxy in a box.

## The Big Picture

The Streambox interacts with VR Site in 2 phases.

### Phase 1: Knocking & Registering (via HTTPS/REST)

Default Endpoint: `https://voicerepublic.com/api/devices`

#### Knocking Request

**GET /:identifier**

* The request is always performed against the LIVE system, even if the
  box will be used for staging or a dev system.
* `:identifier` is a unique string (the streambox uses the cpu serial)

#### Knocking Response (Example)

```
{
  loglevel: 1,
  endpoint: "https://voicerepublic.com/api/devices"
}
```
* all subsequent request must be performed against the endpoint given
  as endpoint
* the endpoint might container basic auth credentials
* loglevels are the commonly used loglevels (0-5)

#### Registering Request

**POST /**

with payload (example)

```
{
  identifier: "00000000000000000768172641827",
  type:       "Streambox",
  subtype:    "v4"
}
```

* `identifier` is the unique string used during knocking
* `type` is a string naming the client
* `subtype` is a string (could for example be a build number)

#### Registering Response (Example)

```
{
  name: "Nietzsche",
  state: "idle",
  public_ip_address: "1.2.3.4",
  report_interval: 30,
  heartbeat_interval: 5,
  pairing_token: "1234"
}
```

* `name` is the name of the device as given by the user, should be displayed
* `state` is the state of the device, states is either `pairing` or `idle`
* `public_ip_address` the visible public ip (gateway) of the device
* `report_interval` number of seconds between reports
* `heartbeat_interval` number of seconds between heartbeats
* `pairing_token` a token to identify the device during pairing (coming soon)

#### Publish Heartbeat

**PUT /:identifier**

With no payload.

With pauses of n seconds in between heartbeats, where n is given by
`heartbeat_interval` during registering.

#### Publish Report (optional)

**PUT /:identifier/report**

With payload arbitrary payload.

With pauses of n seconds, where n is given by `report_interval` during registering.


## Dependencies

All instructions are based on `raspbian jessie lite`.

*By default, raspbian will automatically resize the partitions on startup. Since we want to create an image with as little overhead as possible, this must be deactivated! See the next section for instructions how to do this.*

* Download zip from https://www.raspberrypi.org/downloads/raspbian/
* unzip
* dd resulting img to sdcard

E.g.
* on Linux:
  * `dd bs=4M if=2016-03-18-raspbian-jessie.img of=/dev/mmcblk0`
* on OSX:
  * `dd bs=4m if=2016-03-18-raspbian-jessie.img of=/dev/rdisk2`
  * please note that you should use rdisk and not disk to address the device, this improves read/write performance considerably
  * also, note that the `m` in `bs=4m` needs to be lowercase in OSX
  * even better is installing gnuutils and using gnu's dd which behaves exactly the same as on Linux (except for the device name).

This will take a while. (It takes almost 5 minutes on my machine.) You
can use `time` to find out how long exactly. Or append `&& aplay
<some-wav>` to get an alert when done.

###  Stop Automatic Resizing on Startup
Do this before writing the image to the sd card!

* mount image
* open file `cmdline.txt`
* remove the part `quiet init=/usr/lib/raspi-config/init_resize.sh`
* save and unmount the image


## Intial Setup on a clean raspbian image

Find the PI in you local network. Connect a display the pi will print
it's ip address during boot. Otherwise `nmap` or `nc` are helpful to
poke around.

Ssh into the pi with forward agent `-A`.

Username `pi`, password `raspberry`.


### Step 1: Become root

    sudo -i SSH_AUTH_SOCK="$SSH_AUTH_SOCK"

*We need to set `SSH_AUTH_SOCK` so that our forwarded ssh agent is available in the new environment created by sudo.*


### Step 2: Main Setup

```
apt-get update
apt-get -y install git

# add ssh directory for root and add gitlabs ssh keys to known_hosts
# this way we avoid manual confirmation of gitlab as unknown host
mkdir -p /root/.ssh
ssh-keyscan gitlab.com >> ~/.ssh/known_hosts
ssh-keyscan gitlab.com >> /home/pi/.ssh/known_hosts

git clone git@gitlab.com:voicerepublic/streambox.git /home/pi/streambox

mkdir -p /etc/systemd/system/default.target.wants
ln -vs /home/pi/streambox/streambox.service \
       /etc/systemd/system/default.target.wants
ln -vs /home/pi/streambox/monitor.service \
       /etc/systemd/system/default.target.wants
mv /etc/systemd/system/getty.target.wants/getty@tty1.service \
   /etc/systemd/system/getty.target.wants/getty@tty3.service
```


### Step 3: Adjust boot params & "bios"

To

    /boot/cmdline.txt

add

    consoleblank=0 quiet

In

    /boot/config.txt

uncomment the line

    hdmi_force_hotplug=1


### Step 4: Type & Subtype

The type of the box is always 'Streambox'.

The subtype is stored in `/home/pi/subtype`.

If you make a change to the box setup, which is not covered by the git
repo, please update the subtype file and the corresponding list of known usb devices.

    echo -n "v0.3prototype" > /home/pi/subtype
    sudo bash -c "lsusb > /home/pi/streambox/lsusb/$(cat /home/pi/subtype)"




### Step 5: raspi-config

* use `sudo raspi-config` to
  * expand file system (only if this installation will not be used as an image)
  * change the user password to `aeg9ethoh0thioji`
  * set timezone to berlin (for now)


### Step 6: Reboot

If the previous step didn't cause a reboot, reboot!

    reboot


## Helpful commands

### Force Restart (kill running ruby processes)

    sudo killall ruby


### Force Update (if auto update is broken)

    (cd streambox && git pull) && sudo reboot


## Duplication

### Create an image

    dd if=/dev/mmcblk00 of=2016-06-14_streambox_small.img bs=32M iflag=fullblock count=42 status=progress

This ensures that only 42 * 32 MB are written, which is about 1.4 GB. This is important, because otherwise the image will have the full size of the SD card it is copied from.

For OSX specific command, see [Dependencies](#dependencies).


### Write that image to a new card

    dd bs=4M of=/dev/mmcblk0 if=streambox_v0-3prototype.img

For OSX specific command, see [Dependencies](#dependencies).


## Once and only once, I had to do this...

Create a deploy key

    ssh-keygen -t rsa -C boxed key

Add the public key to this repo on GitLab.

Check both keys (public and private) into this repo.


## TODO

* for production boxes make commands in scripts silent
* set the timezone of organization/venue
  * https://www.raspberrypi.org/forums/viewtopic.php?t=4977&f=5
* `sudo dpkg --configure -a` sometimes helps and seems idempotent
* `sudo bing -e 200 localhost voicerepublic.com`
* What happens if we `bing` from behind a FW?

```
wget -c https://github.com/raboof/nethogs/archive/v0.8.5.tar.gz
tar xf v0.8.5.tar.gz
cd ./nethogs-0.8.5/
sudo apt-get -y install libncurses5-dev libpcap-dev
make && sudo make install
nethogs -V
sudo nethogs
```


`sudo streambox/switch_to_repo.sh fix/wifi-ap`



## References

* https://www.raspberrypi.org/documentation/configuration/config-txt.md


## Thought experiements

### Upgrade from pre-liquidsoap

1. (prod only) box starts in pre-liquidsoap, ruby starts & detects a new release
1. (prod only) box installs the new (liquidsoap-)release
1. (prod only) box reboots (reboot if from-version < 40)
1. (dev only) git pull, switch to branch liguidsoap & reboot
1. box boots into new (liquidsoap-)release
1. the launcher installs & starts the `liquidsoap.service`
1. the service attempts to start liquidsoap, which fails because it isn't installed yet
1. the `launcher.sh` enables `liquidsoap.service` so it will be run on next boot
1. the `launcher.sh` places `minimal.liq` in place of `~pi/streamboxx.liq`
1. `launcher.sh` runs `start.sh`
1. `start.sh` runs `setup.sh`
1. `setup.sh` runs `install_liquidsoap.sh` (this will take a while, check tty1)
1. while installing/building liquidsoap the service keeps on restarting liquidsoap
1. when the build finishes, systemd succeeds in starting liquidsoap (with `minimal.liq`)
1. at this point you can see liquidsoap running on tty3
1. liquidsoap is recording (if there is a audio input with enough volume, check tty1)
1. at this point you can here audio via the raspi headphone jack
1. ruby starts & waits for icecast details
1. at this point you need to set up a talk and select the streambox as source
1. ruby receives new details, updates `~pi/streamboxx.liq`
1. liquidsoap restarts itself (monitoring `~pi/streamboxx.liq`) & starts streaming
1. liquidsoap will also try to post events to a new endpoint which is currently only availabe in dev, this might yield some error messages


## Glossary

* DSD   - Direct Stream Digital
* DoP   - DSD over PCM
* PCM   - Pulse-code modulation
* PWM   - Pulse Width Modulation
* CPLD  - complex programmable logic device
* DAC   - Digital Analog Converter
* ADC   - Analog Digital Converter
* I2S   - Inter-IC Sound
* SPDIF - Sony/Philips Digital Interface Format
* ASoC  - ALSA System on Chip
* DAI   - Direct Audio Input
* SPI   - Serial Peripheral Interface bus
* I2C   - Inter-Integrated Circuit
* DPAM  - Dynamic Audio Power Management (ALSA)

## Upgrade RasPI

As root (time to grab a coffee, this will take a while)

```
apt-get update
apt-get -y dist-upgrade
apt-get -y install raspberrypi-kernel-headers
apt-get -y install linux-image-rpi-rpfv linux-headers-rpi-rpfv
cd /lib/modules/`uname -r`/build
make menuconfig
```
Follow the instructions to enable modules

* https://wiki.analog.com/resources/tools-software/linux-drivers/sound/ssm2602

```
make modules
```

## References

* https://www.alsa-project.org/main/index.php/ASoC


## Cross Compile A Kernel for RasPI

```
git clone https://github.com/raspberrypi/tools
```
