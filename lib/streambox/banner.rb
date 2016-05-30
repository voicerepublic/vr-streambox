module Streambox

  class Banner

    CLAIMS = [
      'War is Peace; Freedom is Slavery; Ignorance is Strength.'
    ]

    def initialize
      system('figlet -t "%s"' % claim)
    end

    def claim
      CLAIMS[rand(CLAIMS.size)]
    end

  end
end
