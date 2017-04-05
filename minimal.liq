#!/usr/bin/liquidsoap -v

set("log.file.path", "./liquidsoap.log")
# set("log.stdout", true)

# ------------------------------ SETTINGS

alsa_device = "hw:1,0" # assumption

stream = input.alsa(device=alsa_device)

# ------------------------------ PROCESSING

stream = mic_filter(stream)
stream = nrj(stream)
stream = clip(stream)

enhanced = strip_blank(stream, max_blank=10.)

# ------------------------------ OUTPUT

output.alsa(fallible=true, enhanced) # local monitoring

output.file(
  %vorbis,
  "./recordings/rec_%Y%m%d_%H%M%S.ogg",
  reopen_when={0m0s}, # rotate on the full hour
  fallible=true,
  enhanced
)

# ------------------------------ LIQUIDSOAP RELOAD

# We call it with
#
#   liquidsoap streamboxx.liq
#
# so the first argument will be the file to watch.
main_file = argv(0)

def restart_if_valid()
  if test_process("liquidsoap -c #{main_file}") then
    restart()
  else
    log("Error parsing #{main_file}")
    system("liquidsoap -c #{main_file}")
  end
end

ignore(file.watch(main_file, restart_if_valid))
