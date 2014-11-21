require "json"
require "http2"
require "string-cases"
require "timeout"
require "cgi"
require "tretry"

class ApsisOnSteroids
  STRFTIME_FORMAT = "%Y%m%dT%H%M%S"

  attr_reader :http

  def self.const_missing(name)
    require "#{File.dirname(__FILE__)}/../include/#{::StringCases.camel_to_snake(name)}"
    raise "Still not loaded: '#{name}'." unless ApsisOnSteroids.const_defined?(name)
    return ApsisOnSteroids.const_get(name)
  end

  def initialize(args)
    raise "Invalid API key: '#{args[:api_key]}' from: '#{args}'." if args[:api_key].to_s.strip.empty?

    @args = args
    reconnect

    if block_given?
      begin
        yield self
      ensure
        @http.destroy
        @http = nil
      end
    end
  end

  def new_url_builder
    ub = ::Http2::UrlBuilder.new
    ub.protocol = "https"
    ub.port = "8443"
    ub.host = "se.api.anpdm.com"

    return ub
  end

  # Closes connection and removes all references to resource-objects.
  def destroy
    @http.destroy if @http
    @http = nil
  end

  def debugs(str)
    puts str if @args[:debug]
  end

  def mailing_lists
    res = req_json("v1/mailinglists/1/999")

    ret = []
    res["Result"]["Items"].each do |mlist|
      ret << ApsisOnSteroids::MailingList.new(
        aos: self,
        data: mlist
      )
    end

    return ret
  end

  def create_mailing_list(data)
    res = req_json("v1/mailinglists/", :post, json: data)
    if res["Code"] == 1
      # Success!
    else
      raise "Unexpected result: '#{res}'."
    end
  end

  def sendings_by_date_interval(date_from, date_to)
    date_from_str = date_from.strftime(STRFTIME_FORMAT)
    date_to_str = date_to.strftime(STRFTIME_FORMAT)

    Enumerator.new do |yielder|
      res = req_json("v1/sendqueues/date/from/#{date_from_str}/to/#{date_to_str}")

      res["Result"].each do |sending_data|
        sending = ApsisOnSteroids::Sending.new(
          aos: self,
          data: sending_data
        )

        yielder << sending
      end
    end
  end

  def mailing_list_by_name(name)
    mailing_lists.each do |mlist|
      return mlist if name.to_s == mlist.data(:name).to_s
    end

    raise "Could not find mailing list by that name: '#{name}'."
  end

  def mailing_list_by_id(id)
    tried_ids = []
    mailing_lists.each do |mailing_list|
      return mailing_list if mailing_list.data(:id) == id.to_i
      tried_ids << mailing_list.data(:id)
    end

    raise "Mailing list by that ID could not be found: #{id} in list #{tried_ids}"
  end

  def subscriber_by_email(email)
    begin
      res = req_json("subscribers/v2/email", :post, json: email)
    rescue
      raise ApsisOnSteroids::Errors::SubscriberNotFound, "Could not find subscriber by that email in the system: '#{email}'."
    end

    sub = ApsisOnSteroids::Subscriber.new(
      aos: self,
      data: {
        "Id" => res["Result"],
        "Email" => email
      }
    )

    return sub
  end

  def req_json(url, type = :get, method_args = {})
    # Parse arguments, send and parse the result.
    args = {url: url.start_with?('/') ? url[1..-1] : url}.merge(method_args)
    try = ::Tretry.new
    try.timeout = 300

    if type == :get
      try.tries = 3
      try.before_retry { @http.reconnect }
    else
      # Don't retry a manipulatable method!
      try.tries = 1
    end

    res = nil
    try.try do
      http_res = @http.__send__(type, args)

      # Throw custom JSON error for debugging if the JSON was corrupt (this actually happens!).
      begin
        res = JSON.parse(http_res.body)
      rescue JSON::ParserError
        raise "Invalid JSON given: '#{http_res.body}'."
      end
    end

    # Check for various kind of server errors and raise them as Ruby errors if present.
    raise "Failed on server with code #{res["Code"]}: #{res["Message"]}" if res.is_a?(Hash) && res.key?("Code") && res["Code"] < 0
    raise "Failed on server with state #{res["State"]} and name '#{res["StateName"]}': #{res["Message"]}" if res.is_a?(Hash) && res.key?("State") && res["State"].to_i < 0

    # Return the result.
    return res
  end

  def read_queued_response(url)
    uri = URI.parse(url)

    Timeout.timeout(300) do
      loop do
        sleep 1
        res = req_json(uri.path)

        if res["State"] == "2"
          uri_data = URI.parse(res["DataUrl"])
          return req_json(uri_data.path)
        elsif res["State"] == "1" || res["State"] == "0"
          # Keep waiting.
        else
          raise "Unknown state '#{res["State"]}': #{res}"
        end
      end
    end
  end

  def read_resources_from_array(resource_class_name, resource_array)
    Enumerator.new do |yielder|
      resource_array.each do |resource_data|
        resource = ApsisOnSteroids.const_get(resource_class_name).new(aos: self, data: resource_data)
        yielder << resource
      end
    end
  end

  def parse_obj(obj)
    if obj.is_a?(Array)
      ret = []
      obj.each do |obj_i|
        ret << parse_obj(obj_i)
      end

      return ret
    elsif obj.is_a?(Hash)
      ret = {}
      obj.each do |key, val|
        ret[key] = parse_obj(val)
      end

      return ret
    elsif obj.is_a?(String)
      # Automatically convert dates.
      if match = obj.match(/^\/Date\((\d+)\+(\d+)\)\/$/)
        unix_t = match[1].to_i / 1000
        return Time.at(unix_t)
      elsif match = obj.match(/^\/Date\((\d+)\)\/$/)
        unix_t = match[1].to_i / 1000
        return Time.at(unix_t)
      end

      return obj
    else
      return obj
    end
  end

private

  def reconnect
    @http.destroy if @http

    @http = Http2.new(
      host: "se.api.anpdm.com",
      port: 8443,
      ssl: true,
      follow_redirects: false,
      debug: @args[:debug],
      extra_headers: {
        "Accept" => "text/json, application/json"
      },
      basic_auth: {
        user: @args[:api_key],
        passwd: ""
      },
      skip_port_in_host_header: true
    )
  end
end
