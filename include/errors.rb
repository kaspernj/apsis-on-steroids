class ApsisOnSteroids::Errors
  class HttpError < RuntimeError
    attr_accessor :http_response

    def self.http_error_from_response(args)
      error = ApsisOnSteroids::Errors::HttpError.new(args[:message] || "Unexpected result")
      error.http_response = args.fetch(:response)

      raise error
    end
  end

  class SubscriberNotFound < RuntimeError; end
end
