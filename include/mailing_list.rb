require "uri"

class ApsisOnSteroids::MailingList < ApsisOnSteroids::SubBase
  def create_subscribers(data)
    res = aos.req_json("v1/subscribers/mailinglist/#{data(:id)}/queue", :post, json: data)

    url = URI.parse(res["Result"]["PollURL"])
    data_subscribers = nil

    Timeout.timeout(300) do
      loop do
        sleep 1
        res = aos.req_json(url.path)
        debugs "Result: #{res}"

        if res["State"] == "2"
          data_url = URI.parse(res["DataUrl"])
          data_subscribers = aos.req_json(data_url.path)
          break
        elsif res["State"] == "0" || res["State"] == "1"
          # Keep waiting.
        else
          raise "Unknown state: '#{res["State"]}': #{res}."
        end
      end
    end

    data_subscribers
  end

  # Returns the subscribers of the mailing list.
  def subscribers
    res = aos.req_json("v1/mailinglists/#{data(:id)}/subscribers/all", :post, json: {
      "AllDemographics" => false,
      "FieldNames" => []
    })

    url = URI.parse(res["Result"]["PollURL"])
    data_subscribers = nil

    Timeout.timeout(300) do
      loop do
        sleep 1
        res = aos.req_json(url.path)

        if res["State"] == "2"
          data_url = URI.parse(res["DataUrl"])
          data_subscribers = aos.req_json(data_url.path)
          break
        elsif res["State"] == "0" || res["State"] == "1"
          # Keep waiting.
        else
          raise "Unknown state: '#{res["State"]}': #{res}."
        end
      end
    end

    ret = []
    data_subscribers.each do |sub_data|
      sub = ApsisOnSteroids::Subscriber.new(
        aos: self.aos,
        data: aos.parse_obj(sub_data)
      )

      if block_given?
        yield sub
      else
        ret << sub
      end
    end

    return ret
  end

  # Adds the given email as a new subscriber and subscribes the created subscriber to the mailing list.
  def subscriber_by_email(email)
    sub = aos.subscriber_by_email(email)

    res = aos.req_json("v1/subscribers/#{sub.data(:id)}/mailinglists")
    if res["Result"]
      mailinglist_ids = res["Result"]["Mailinglists"].map { |m| m["Id"].to_i }
      return sub if mailinglist_ids.include?(self.data(:id))
    end

    raise "Could not find subscriber by that email: '#{email}' on this mailing list '#{self.data(:name)}'."
  end

  # Adds the given subscriber to the mailing list.
  def add_subscriber(subscriber)
    res = aos.req_json("v1/mailinglists/#{self.data(:id)}/subscriptions/#{subscriber.data(:id)}", :post)
    if res["Message"] == "Succesfully created Subscription"
      res["Result"].to_i > 0
    else
      raise "Unexpected result: '#{res["Result"]}'."
    end
  end

  # Removes the given subscriber from the mailing list.
  def remove_subscriber(subscriber)
    res = aos.req_json("v1/mailinglists/#{self.data(:id)}/subscriptions/#{subscriber.data(:id)}", :delete)
    if res["Message"] == "Successfully deleted Subscription"
      true
    else
      raise "Unexpected result: '#{res["Result"]}'."
    end
  end

  # Removes all subscribers from the mailing list.
  def remove_all_subscribers
    res = aos.req_json("v1/mailinglists/#{self.data(:id)}/subscriptions/all", :delete)
    raise "Unexpected result: #{res}" if res["Code"] != 1
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

    return nil
  end

  def count_subscribers
    res = aos.req_json("v1/mailinglists/#{self.data(:id)}/subscriptions/count")
    raise "Unexpected result: #{res}" if res["Code"] != 1
    return res["Result"]
  end

  # Returns true if the given subscriber is a member of the mailing list.
  def member?(sub)
    sub.mailing_lists.each do |mlist|
      if mlist.data(:id) == self.data(:id)
        return true
      end
    end

    return false
  end

  # Deletes the mailing list from APSIS.
  def delete
    res = aos.req_json("v1/mailinglists/", :delete, json: [data(:id)])

    url = URI.parse(res["Result"]["PollURL"])
    data = nil

    Timeout.timeout(300) do
      loop do
        sleep 1
        res = aos.req_json(url.path)

        if res["State"] == "2"
          data_url = URI.parse(res["DataUrl"])
          data = aos.req_json(data_url.path)
          break
        elsif res["State"] == "0" || res["State"] == "1"
          # Keep waiting.
        else
          raise "Unknown state: '#{res["State"]}': #{res}"
        end
      end
    end

    data.each do |element|
      raise "Unexpected result: '#{data}'." if element["Value"] != "Succefully deleted"
    end
  end

  # Moves a subscriber to the opt-out-list.
  def opt_out_subscriber(sub)
    res = aos.req_json("v1/optouts/mailinglists/#{data(:id)}/subscribers/queued", :post, json: [{
      "ExternalId" => "",
      "Reason" => "",
      "SendQueueId" => 0,
      "SubscriberId" => sub.data(:id)
    }])
    raise "Unexpected result: #{res}" if res["Code"] != 1
    data = aos.read_queued_response(res["Result"]["PollURL"])

    raise data if data["FailedSubscriberIds"] && data["FailedSubscriberIds"].any?
  end

  # Returns a list of subscribers on the opt-out-list.
  def opt_out_list
    res = aos.req_json("v1/optouts/mailinglists/#{data(:id)}/queued", :post)
    raise "Unexpected result: #{res}" if res["Code"] != 1
    data = aos.read_queued_response(res["Result"]["PollURL"])

    ret = []
    data.each do |opt_out_data|
      sub = ApsisOnSteroids::Subscriber.new(aos: aos, data: {id: opt_out_data["Id"], email: opt_out_data["Email"]})

      if block_given?
        yield sub
      else
        ret << sub
      end
    end

    return ret
  end

  # Returns true if the given subscriber is on the opt-out-list.
  def opt_out?(sub)
    opt_out_list do |sub_opt_out|
      return true if sub_opt_out.data(:email) == sub.data(:email) || sub.data(:id).to_i == sub_opt_out.data(:id).to_i
    end

    return false
  end

  # Removes the given subscriber from the opt-out-list.
  def opt_out_remove_subscriber(sub)
    res = aos.req_json("v1/optouts/mailinglists/#{data(:id)}/subscribers/queued", :delete, json: [
      sub.data(:email)
    ])
    data = aos.read_queued_response(res["Result"]["PollURL"])
    raise data if data["FailedSubscriberEmails"] && data["FailedSubscriberEmails"].any?
  end
end
