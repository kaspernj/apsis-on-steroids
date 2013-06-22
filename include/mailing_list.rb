class ApsisOnSteroids::MailingList < ApsisOnSteroids::SubBase
  def create_subscribers(data)
    aos.req_json("v1/subscribers/mailinglist/#{data(:id)}/queue", :post, :json => data)
  end
  
  def subscribers
    res = aos.req_json("v1/mailinglists/#{data(:id)}/subscribers/all", :post, :json => {
      "AllDemographics" => false,
      "FieldNames" => []
    })
    
    url = URI.parse(res["Result"]["PollURL"])
    
    Timeout.timeout(30) do
      loop do
        sleep 0.5
        res = aos.req_json(url.path)
        
        puts "Status res: #{res}"
        
        if res["State"] == "2"
          break
        end
      end
    end
    
    puts "Test: #{res}"
    raise "Finish me!"
  end
  
  def subscriber_by_email(email)
    self.subscribers.each do |sub|
      if sub.data(:email).to_s.downcase.strip == email.to_s.downcase.strip
        return sub
      end
    end
    
    raise "Could not find subscriber by that email: '#{email}' on this mailing list '#{self.data(:name)}'."
  end
  
  def remove_subscriber(subscriber)
    res = aos.req_json("v1/mailinglists/#{self.data(:id)}/subscriptions/#{subscriber.data(:id)}", :delete)
    if res["Result"] == "Deleted"
      return nil
    else
      raise "Unexpected result: '#{res["Result"]}'."
    end
  end
  
  def delete
    res = aos.req_json("v1/mailinglists/", :delete, :json => [data(:id)])
    
    url = URI.parse(res["Result"]["PollURL"])
    data = nil
    
    Timeout.timeout(30) do
      loop do
        sleep 0.5
        res = aos.req_json(url.path)
        
        if res["State"] == "2"
          data_url = URI.parse(res["DataUrl"])
          data = aos.req_json(data_url.path)
          break
        end
      end
    end
    
    data.each do |element|
      raise "Unexpected result: '#{data}'." if element["Value"] != "Succefully deleted"
    end
  end
end
