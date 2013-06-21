class ApsisOnSteroids::MailingList < ApsisOnSteroids::SubBase
  def create_subscribers(data)
    aos.req_json("v1/subscribers/mailinglist/#{data(:id)}/queue", :post, :json => data)
  end
  
  def subscribers
    res = aos.req_json("v1/mailinglists/#{data(:id)}/subscribers/all", :post, :json => {
      "AllDemographics" => true,
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
  
  def remove_subscriber(subscriber)
    res = aos.req_json("v1/mailinglists/#{self.data(:id)}/subscriptions/#{subscriber.data(:id)}", :delete)
    if res["Result"] == "Deleted"
      return nil
    else
      raise "Unexpected result: '#{res["Result"]}'."
    end
  end
end