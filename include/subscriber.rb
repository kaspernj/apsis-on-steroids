class ApsisOnSteroids::Subscriber < ApsisOnSteroids::SubBase
  # Fetches the details from the server and returns them.
  def details
    if !@details
      res = aos.req_json("v1/subscribers/id/#{data(:id)}")
      
      ret = {}
      res["Result"].each do |key, val|
        ret[key.to_sym] = val
      end
      
      @details = ret
    end
    
    return @details
  end
  
  # Returns the DemDataField by the given key.
  def dem_data(key)
    key = key.to_s.downcase
    
    self.details[:DemDataFields].each do |dem_data|
      if dem_data["Key"].to_s.downcase == key
        return dem_data["Value"]
      end
    end
    
    return nil
  end
  
  # Returns true if the subscriber is active.
  def active?
    details = self.details
    return false if details[:pending]
    return true
  end
  
  # Update one or more details on the subscriber.
  def update(data)
    begin
      res = aos.req_json("v1/subscribers/queue", :post, :json => [data.merge(:Id => self.data(:id))])
      url = URI.parse(res["Result"]["PollURL"])
      data = nil
      
      Timeout.timeout(300) do
        loop do
          sleep 1
          res = aos.req_json(url.path)
          
          if res["State"] == "2"
            url_data = URI.parse(res["DataUrl"])
            data = aos.req_json(url_data.path)
            break
          elsif res["State"] == "0" || res["State"] == "1"
            # Keep waiting.
          else
            raise "Unknown state '#{res["State"]}': #{res}"
          end
        end
      end
      
      if data["FailedUpdatedSubscribers"] && data["FailedUpdatedSubscribers"].any?
        msg = raise data["FailedUpdatedSubscribers"].to_s
        
        if msg.include?("Timeout expired.")
          raise Errno::EAGAIN, msg
        else
          raise msg
        end
      end
    rescue Errno::EAGAIN
      retry
    end
    
    @details = nil
    return nil
  end
  
  # Returns an array of mailing lists that the sucscriber is subscribed to.
  def mailing_lists
    ret = []
    
    res = aos.req_json("v1/subscribers/#{self.data(:id)}/mailinglists")
    raise "Unexpected result: #{res}" if res["Code"] != 1 || !res["Result"].is_a?(Hash)
    
    res["Result"]["Mailinglists"].each do |mlist_data|
      mlist = ApsisOnSteroids::MailingList.new(:data => mlist_data, :aos => aos)
      ret << mlist
    end
    
    return ret
  end
end
