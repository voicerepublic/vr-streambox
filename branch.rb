require 'json'
require 'faraday'

ENDPOINT = 'https://voicerepublic.com/api/devices'

def identifier
  return @serial unless @serial.nil?
  md = File.read('/proc/cpuinfo').match(/Serial\s*:\s*(.*)/)
  @serial = md.nil? ? serial_fallback : md[1]
end

def serial_fallback
  [%x[ whoami ].chomp, %x[ hostname ].chomp] * '@'
end

def expected_branch
  return @branch unless @branch.nil?
  url = ENDPOINT + '/' + identifier
  response = faraday.get(url)
  br = JSON.parse(response.body)[:branch]
  @branch = br.nil? ? 'master' : br
end

def current_branch
  %x(git rev-parse --abbrev-ref HEAD)
end

def change_git_branch(name)
  %x(git checkout #{name}) if branch? name
end

def branch?(name)
  %x(git branch --list #{name}) != ""
end

change_git_branch(expected_branch) unless current_branch == expected_branch