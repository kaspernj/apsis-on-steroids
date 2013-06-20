require "json"
require "http2"
require "string-cases"
require "timeout"

class ApsisOnSteroids
  attr_reader :http
  
  def self.const_missing(name)
    require "#{File.dirname(__FILE__)}/../include/#{::StringCases.camel_to_snake(name)}"
    raise "Still not loaded: '#{name}'." unless ApsisOnSteroids.const_defined?(name)
    return ApsisOnSteroids.const_get(name)
  end
  
  def initialize(args)
    @args = args
    @http = Http2.new(
      :host => "se.api.anpdm.com",
      :port => 8443,
      :ssl => true,
      :follow_redirects => false,
      :debug => true,
      :extra_headers => {
        "Accept" => "text/json, application/json"
      },
      :basic_auth => {
        :user => @args[:api_key],
        :passwd => ""
      }
    )
    
    if block_given?
      begin
        yield self
      ensure
        @http.destroy
        @http = nil
      end
    end
  end
  
  def mailing_lists
    res = req_json("v1/mailinglists/1/10")
    
    ret = []
    res["Result"]["Items"].each do |mlist|
      ret << ApsisOnSteroids::MailingList.new(
        :aos => self,
        :data => mlist
      )
    end
    
    return ret
  end
  
  def mailing_list_by_name(name)
    self.mailing_lists.each do |mlist|
      return mlist if name.to_s == mlist.name.to_s
    end
    
    raise "Could not find mailing list by that name: '#{name}'."
  end
  
  def create_mailing_list(args)
    raise "stub!"
  end
  
  def req_json(url, type = :get, method_args = {})
    # Parse arguments, send and parse the result.
    args = {:url => url}.merge(method_args)
    http_res = @http.__send__(type, args)
    res = JSON.parse(http_res.body)
    
    # Check for various kind of server errors and raise them as Ruby errors if present.
    raise "Failed on server with code #{res["Code"]}: #{res["Message"]}" if res.key?("Code") && res["Code"] < 0
    raise "Failed on server with state #{res["State"]} and name '#{res["StateName"]}': #{res["Message"]}" if res.key?("State") && res["State"].to_i < 0
    
    # Return the result.
    return res
  end
end