class ApsisOnSteroids::Subscriber < ApsisOnSteroids::SubBase
  # Fetches the details from the server and returns them.
  def details
    unless @details
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

    dem_data_fields.each do |dem_data|
      return dem_data["Value"] if dem_data["Key"].to_s.downcase == key
    end

    return nil
  end

  def dem_data_fields
    @dem_data_fields ||= details[:DemDataFields]
  end

  # Returns true if the subscriber is active.
  def active?
    return false if details[:pending]
    return true
  end

  # Update one or more details on the subscriber.
  def update(data)
    begin
      res = aos.req_json("v1/subscribers/queue", :post, json: [data.merge(:Id => self.data(:id))])
      url = URI.parse(res["Result"]["PollURL"])
      result = nil

      Timeout.timeout(300) do
        loop do
          sleep 1
          data = aos.req(url.path)
          res = data.fetch(:json)

          if res["State"] == "2"
            url_data = URI.parse(res.fetch("DataUrl"))
            result = aos.req_json(url_data.path)
            break
          elsif res["State"] == "0" || res["State"] == "1"
            # Keep waiting.
          else
            raise "Unknown state '#{res["State"]}': #{res}"
          end
        end
      end

      if result["FailedUpdatedSubscribers"] && result["FailedUpdatedSubscribers"].any?
        msg = result["FailedUpdatedSubscribers"].to_s

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
      mlist = ApsisOnSteroids::MailingList.new(data: mlist_data, aos: aos)
      ret << mlist
    end

    return ret
  end
end
