class ApsisOnSteroids::Errors
  class HttpError < RuntimeError
    attr_accessor :http_response

    def self.http_error_from_response(args)
      error = ApsisOnSteroids::Errors::HttpError.new("Unexpected result: '#{res["Result"]}'.")
      error.http_response = args.fetch(:response)

      raise error
    end
  end

  class SubscriberNotFound < RuntimeError; end
end
