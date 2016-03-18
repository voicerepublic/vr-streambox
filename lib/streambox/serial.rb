class Streambox
  module Serial

    extend self

    def serial
      output = %[#{cmd}]
    end

    private

    def cmd
      'sudo dmidecode'
    end
