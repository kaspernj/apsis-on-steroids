class ApsisOnSteroids::MailingList < ApsisOnSteroids::SubBase
  def create_subscribers(data)
    res = aos.req_json("v1/subscribers/mailinglist/#{data(:id)}/queue", :post, :json => data)

    url = URI.parse(res["Result"]["PollURL"])
    data_subscribers = nil
    
    Timeout.timeout(30) do
      loop do
        sleep 0.5
        res = aos.req_json(url.path)

        if res["State"] == "2"
          data_url = URI.parse(res["DataUrl"])
          data_subscribers = aos.req_json(data_url.path)
          break
        end
      end
    end

    data_subscribers
  end
  
  def subscribers
    res = aos.req_json("v1/mailinglists/#{data(:id)}/subscribers/all", :post, :json => {
      "AllDemographics" => false,
      "FieldNames" => []
    })
    
    url = URI.parse(res["Result"]["PollURL"])
    data_subscribers = nil
    
    Timeout.timeout(30) do
      loop do
        sleep 0.5
        res = aos.req_json(url.path)

        if res["State"] == "2"
          data_url = URI.parse(res["DataUrl"])
          data_subscribers = aos.req_json(data_url.path)
          break
        end
      end
    end

    data_subscribers
  end
  
  def subscriber_by_email(email)
    sub = aos.subscriber_by_email(email)

    res = aos.req_json("v1/subscribers/#{sub.data(:id)}/mailinglists")
    if res["Result"]
      mailinglist_ids = res["Result"]["Mailinglists"].map { |m| m["Id"].to_i }
      return sub if mailinglist_ids.include?(self.data(:id))
    end
    
    raise "Could not find subscriber by that email: '#{email}' on this mailing list '#{self.data(:name)}'."
  end

  def add_subscriber(subscriber)
    res = aos.req_json("v1/mailinglists/#{self.data(:id)}/subscriptions/#{subscriber.data(:id)}", :post)
    if res["Message"] == "Succesfully created Subscription"
      res["Result"].to_i > 0
    else
      raise "Unexpected result: '#{res["Result"]}'."
    end
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
