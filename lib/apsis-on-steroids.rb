require "json"
require "http2"
require "string-cases"
require "timeout"
require "cgi"

class ApsisOnSteroids
  attr_reader :http
  
  def self.const_missing(name)
    require "#{File.dirname(__FILE__)}/../include/#{::StringCases.camel_to_snake(name)}"
    raise "Still not loaded: '#{name}'." unless ApsisOnSteroids.const_defined?(name)
    return ApsisOnSteroids.const_get(name)
  end
  
  def initialize(args)
    raise "Invalid API key: '#{args[:api_key]}' from: '#{args}'." if args[:api_key].to_s.strip.empty?
    
    @args = args
    @http = Http2.new(
      :host => "se.api.anpdm.com",
      :port => 8443,
      :ssl => true,
      :follow_redirects => false,
      :debug => args[:debug],
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
    res = req_json("v1/mailinglists/1/999")
    
    ret = []
    res["Result"]["Items"].each do |mlist|
      ret << ApsisOnSteroids::MailingList.new(
        :aos => self,
        :data => mlist
      )
    end
    
    return ret
  end
  
  def create_mailing_list(data)
    res = req_json("v1/mailinglists/", :post, :json => data)
    if res["Code"] == 1
      # Success!
    else
      raise "Unexpected result: '#{res}'."
    end
  end
  
  def mailing_list_by_name(name)
    self.mailing_lists.each do |mlist|
      return mlist if name.to_s == mlist.data(:name).to_s
    end
    
    raise "Could not find mailing list by that name: '#{name}'."
  end
  
  def subscribers
    # Request a list of all subs.
    res = req_json("v1/subscribers/all", :post, :json => {
      "AllDemographics" => true,
      "FieldNames" => []
    })
    
    # Wait for the server to generate the list.
    url = URI.parse(res["Result"]["PollURL"])
    data = nil
    
    Timeout.timeout(30) do
      loop do
        sleep 0.5
        res = req_json(url.path)
        
        if res["State"] == "2"
          url_data = URI.parse(res["DataUrl"])
          data = req_json(url_data.path)
          break
        end
      end
    end
    
    # Parse the list of subscribers.
    ret = [] unless block_given?
    
    data.each do |sub_data|
      sub = ApsisOnSteroids::Subscriber.new(
        :aos => self,
        :data => sub_data
      )
      
      if block_given?
        yield sub
      else
        ret << sub
      end
    end
    
    if block_given?
      return nil
    else
      return ret
    end
  end
  
  def subscriber_by_email(email)
    res = req_json("v1/subscribers/email/lookup/#{CGI.escape(email)}")
    
    sub = ApsisOnSteroids::Subscriber.new(
      :aos => self,
      :data => {
        "Id" => res["Result"],
        "Email" => email
      }
    )
    
    return sub
  end
  
  def req_json(url, type = :get, method_args = {})
    # Parse arguments, send and parse the result.
    args = {:url => url}.merge(method_args)
    http_res = @http.__send__(type, args)
    
    begin
      res = JSON.parse(http_res.body)
    rescue JSON::ParserError
      raise "Invalid JSON given: '#{http_res.body}'."
    end
    
    # Check for various kind of server errors and raise them as Ruby errors if present.
    raise "Failed on server with code #{res["Code"]}: #{res["Message"]}" if res.is_a?(Hash) && res.key?("Code") && res["Code"] < 0
    raise "Failed on server with state #{res["State"]} and name '#{res["StateName"]}': #{res["Message"]}" if res.is_a?(Hash) && res.key?("State") && res["State"].to_i < 0
    
    # Return the result.
    return res
  end
end
