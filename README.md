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
  faye_url: "https://voicerepublic.com:9292/faye",
  faye_secret: "12345678987654321",
  pairing_token: "1234"
}
```

* `name` is the name of the device as given by the user, should be displayed
* `state` is the state of the device, states is either `pairing` or `idle`
* `public_ip_address` the visible public ip (gateway) of the device
* `report_interval` number of seconds between reports
* `heartbeat_interval` number of seconds between heartbeats
* `faye_url` the url to the faye server
* `faye_secret` the faye secret
* `pairing_token` a token to identify the device during pairing (coming soon)

NOTE: Faye setup is subject to change, for security reasons.

### Phase 2: Start & Stop Stream (via Faye)

#### Subscription

Using the faye details acquired upon registering, the device has to
subscribe to the following channel:

    /device/:identifier

Most messages follow the following pattern (but some don't):

* the key `event` describes the type of message
* the key named after the value of `event` holds further details
* events (as used in the streambox)
  * `start_stream` - starts the stream, details in key `icecast`
  * `stop_stream` - stops the stream
  * `restart_stream` - stops and starts with previous parameters
  * `eval` - evals the code provided in `eval`
  * `exit` - exits the ruby process (will be restarted)
  * `shutdown` - shuts the box down
  * `reboot` - reboots the box
  * `print` - print (only in loglevel debug)
  * `heartbeat` (deprecated)
  * `report` (deprecated)
  * `error` - ?
  * `handshake` - ?

`start_stream` `icecast` example:

```
{
  event: "start_stream",
  icecast: {
    public_ip_address: "1.2.3.4",
    source_password: "kahsdkjs",
    mount_point: "1732673-1298736821-19283792-1263",
    port: 80
  }
}
```

#### Publish Heartbeat (required)

The box publishes a heartbeat to channel

    /heartbeat

with payload (example)

```
{
  identifier: "00000000000087434573245",
  interval: 5
}
```

with pauses of n seconds in between heartbeats, where n is given by
`heartbeat_interval` during registering.

#### Publish Report (optional)

The box publishes reports to channel

    /report

with payload (example)

```
{
  identifier: "000000000082734873468732",
  interval: 30,
  report: {
    <report details>
  }
}
```

with pauses of n seconds, where n is given by `report_interval` during registering.

* report details depend on the device, but the output of a box can
  comfortably be observed in the back office.
* should/could include:
  * load
  * temperature
  * usb devices
  * audio sources
  * bandwidth
  * ... (more ideas in the icebox of pivotal tracker)


## Dependencies

All instructions are based on `raspbian jessie lite`.

*By default, raspbian will automatically resize the partitions on startup. Since we want to create an image with as little overhead as possible, this should be deactivated! See the next section for instructions how to do this.*

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
ln -s /home/pi/streambox/streambox.service \
      /etc/systemd/system/default.target.wants
mv /etc/systemd/system/getty.target.wants/getty@tty1.service \
   /etc/systemd/system/getty.target.wants/getty@tty2.service
```


### Step 3: Adjust boot params

To

    /boot/cmdline.txt

add

    consoleblank=0 quiet


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
