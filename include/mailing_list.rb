class ApsisOnSteroids::MailingList < ApsisOnSteroids::SubBase
  def create_subscriber(data)
    aos.req_json("v1/subscribers/mailinglist/#{data(:id)}/queue", :post, :json => [data])
  end
  
  def subscribers
    res = aos.req_json("v1/mailinglists/#{data(:id)}/subscribers/all", :post, :json => {
      "AllDemographics" => true,
      "FieldNames" => ["Address", "ZipCode", "City", "Age"]
    })
    
    url = URI.parse(res["Result"]["PollURL"])
    
    Timeout.timeout(5) do
      loop do
        sleep 0.5
        res = aos.req_json(url.path)
        
        puts "Status res: #{res}"
      end
    end
    
    puts "Test: #{res}"
  end
end