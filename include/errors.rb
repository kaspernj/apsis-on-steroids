class ApsisOnSteroids::Errors
  class Error < RuntimeError
    attr_accessor :response

    def self.error(args)
      error = new(args[:message] || "Unexpected result")
      error.response = args[:response]

      raise error
    end
  end

  class InvalidResponse < ApsisOnSteroids::Errors::Error; end
  class InvalidState < ApsisOnSteroids::Errors::Error; end
  class FailedOnServer < ApsisOnSteroids::Errors::Error; end
  class SubscriberNotFound < ApsisOnSteroids::Errors::Error; end
end
