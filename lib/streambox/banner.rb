module Streambox

  class Banner

    CLAIMS = [
      'A stream you stream alone is only a stream. '+
      'A stream you stream together is reality. - John Lennon',

      "I stream. Sometimes I think that's "+
      "the only right thing to do. - Haruki Murakami",

      'I stream my painting and I paint my stream. - Vincent van Gogh',

      "We are the music makers, and we are "+
      "the streamers of streams. - Arthur O'Shaughnessy",

      'The future belongs to those who believe in '+
      'the beauty of their streams. - Eleanor Roosevelt',

      'Hope is a waking stream. - Aristotle',

      'All that we see or seem is but a stream '+
      'within a stream. - Edgar Allen Poe'
    ]

    def initialize
      system('toilet -f future -t "%s"' % claim)
    end

    def claim
      CLAIMS[rand(CLAIMS.size)]
    end

  end
end
