module Flickr
  class Error < RuntimeError
    attr_accessor :code
  end


  class Errors

    # Method used for raising the appropriate error class for a given error code.
    # Currently raises only Flickr::Error
    def self.error_for(code, message)
      raise RuntimeError.new("Internal error. Flickr API error not identified or unknown error.") if (code.nil? || message.nil? || message.empty?)
      raise RuntimeError.new("Internal error. Unknown error.") if code.to_i == 0 # We assume that error code 0 is never returned
      e = Flickr::Error.new("#{code}: #{message}")
      e.code = code
      raise e
    end
  end

end
