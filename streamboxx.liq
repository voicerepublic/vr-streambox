#!/usr/bin/liquidsoap -v

set("log.file.path", "./liquidsoap.log")
set("log.stdout", true)

# This requires liquidsoap 1.2.1
# restart()
# file.watch("icecast.liq", restart)

ignore(http.post(callback_url ^ "/booting"))

# ------------------------------ INPUT

live = input.alsa(clock_safe=false,device=alsa_device);

# after 5 seconds of blank the source will fail
live_stripped = strip_blank(max_blank=5.,live)

interlude = sine(amplitude=0.1,200.)
#interlude = single("./drum.mp3")

stream = fallback(track_sensitive=false,
                  [ live_stripped , interlude ])

enhanced = nrj(mic_filter(mean(stream)))

# ------------------------------ CALLBACKS

def icecast_connect ()
  ignore(http.post(callback_url ^ "/icecast_connect"))
end

def icecast_disconnect ()
  ignore(http.post(callback_url ^ "/icecast_disconnect"))
end

def icecast_error (error)
  ignore(http.post(callback_url ^ "/icecast_error"))
  3. # try again after 3 seconds
end

def icecast_start ()
  ignore(http.post(callback_url ^ "/icecast_start"))
end

def icecast_stop ()
  ignore(http.post(callback_url ^ "/icecast_stop"))
end

def file_start ()
  ignore(http.post(callback_url ^ "/file_start"))
end

def file_stop ()
  ignore(http.post(callback_url ^ "/file_stop"))
end

def file_close (filename)
  ignore(http.post(callback_url ^ "/file_close"))
end

# ------------------------------ OUTPUT

out(enhanced)

output.icecast(
  %vorbis(channels=1),
  port=icecast_port,
  mount=icecast_mount,
  host=icecast_host,
  password=icecast_password,
  public=false,
  on_connect=icecast_connect,
  on_disconnect=icecast_disconnect,
  on_error=icecast_error,
  on_start=icecast_start,
  on_stop=icecast_stop,
  enhanced
)

output.file(
  %vorbis,
  "dump_%Y%m%d_%H%M%S.ogg",
  on_start=file_start,
  on_stop=file_stop,
  on_close=file_close,
  reopen_when={0m0s},
  fallible=true,
  live_stripped
)
