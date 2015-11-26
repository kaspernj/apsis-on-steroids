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

  SUBSCRIBERS_VALID_ARGS = [:all_demographics, :timeout, :field_names, :allow_paginated]

  # Returns the subscribers of the mailing list.
  def subscribers(args = {}, &blk)
    args.each do |key, value|
      raise "Invalid argument: '#{key}'." unless SUBSCRIBERS_VALID_ARGS.include?(key)
    end

    all_demographics = args.key?(:all_demographics) ? args[:all_demographics] : false
    timeout = args[:timeout] || 300
    field_names = args[:field_names] || []
    allow_paginated = args.key?(:allow_paginated) ? args[:allow_paginated] : true

    # Abort and do paginated if no reason to get everything as JSON.
    if allow_paginated && !all_demographics && field_names.empty?
      return subscribers_paginated(&blk)
    end

    data = aos.req("v1/mailinglists/#{data(:id)}/subscribers/all", :post, json: {
      "AllDemographics" => all_demographics,
      "FieldNames" => field_names
    })
    res = data.fetch(:json)
    response = data.fetch(:response)

    url = URI.parse(res["Result"]["PollURL"])
    data_subscribers = nil

    Timeout.timeout(timeout) do
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
          ApsisOnSteroids::Errors::InvalidState.error(
            message: "Unknown state: '#{res["State"]}': #{res}",
            response: response
          )
        end
      end
    end

    ret = []
    data_subscribers.each do |sub_data|
      sub = ApsisOnSteroids::Subscriber.new(
        aos: self.aos,
        data: aos.parse_obj(sub_data)
      )

      if all_demographics || !field_names.empty?
        sub.instance_variable_set(:@dem_data_fields, sub_data["DemographicData"])
      end

      if blk
        blk.call(sub)
      else
        ret << sub
      end
    end

    return ret
  end

  # Returns the subscribers of the mailing list.
  def subscribers_paginated
    resource_url = "v1/mailinglists/#{data(:id)}/subscribers/%{page}/%{size}"

    ret = []
    aos.read_paginated_response(resource_url) do |sub_data|
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

    data = aos.req("v1/subscribers/#{sub.data(:id)}/mailinglists")
    res = data.fetch(:json)

    if res["Result"]
      mailinglist_ids = res["Result"]["Mailinglists"].map { |m| m["Id"].to_i }
      return sub if mailinglist_ids.include?(self.data(:id))
    end

    ApsisOnSteroids::Errors::SubscriberNotFound.error(
      message: "Could not find subscriber by that email: '#{email}' on this mailing list '#{self.data(:name)}'.",
      response: data.fetch(:response)
    )
  end

  # Adds the given subscriber to the mailing list.
  def add_subscriber(subscriber)
    data = aos.req("v1/mailinglists/#{self.data(:id)}/subscriptions/#{subscriber.data(:id)}", :post)
    res = data.fetch(:json)

    if res["Message"] == "Succesfully created Subscription"
      res["Result"].to_i > 0
    else
      ApsisOnSteroids::Errors::InvalidResponse.error(
        message: "Unexpected result: '#{res["Result"]}'.",
        response: data.fetch(:response)
      )
    end
  end

  # Removes the given subscriber from the mailing list.
  def remove_subscriber(subscriber)
    data = aos.req("v1/mailinglists/#{self.data(:id)}/subscriptions/#{subscriber.data(:id)}", :delete)
    res = data.fetch(:json)

    if res["Message"] == "Successfully deleted Subscription"
      true
    else
      ApsisOnSteroids::Errors::InvalidResponse.error(
        message: "Unexpected result: '#{res["Result"]}'.",
        response: data.fetch(:response)
      )
    end
  end

  # Removes all subscribers from the mailing list.
  def remove_all_subscribers
    data = aos.req("v1/mailinglists/#{self.data(:id)}/subscriptions/all", :delete)
    res = data.fetch(:json)

    unless res["Code"] == 1
      ApsisOnSteroids::Errors::InvalidResponse.error(
        message: "Unexpected result: #{res}",
        response: data.fetch(:response)
      )
    end

    url = URI.parse(res.fetch("Result").fetch("PollURL"))
    result = nil

    Timeout.timeout(300) do
      loop do
        sleep 1

        data = aos.req(url.path)
        res = data.fetch(:json)

        if res["State"] == "2"
          url_data = URI.parse(res.fetch("DataUrl"))
          result = aos.req(url_data.path)
          break
        elsif res["State"] == "0" || res["State"] == "1"
          # Keep waiting.
        else
          ApsisOnSteroids::Errors::InvalidResponse.error(
            message: "Unknown state '#{res["State"]}': #{res}",
            response: data.fetch(:response)
          )
        end
      end
    end

    return nil
  end

  def count_subscribers
    data = aos.req("v1/mailinglists/#{self.data(:id)}/subscriptions/count")
    res = data.fetch(:json)

    unless res["Code"] == 1
      ApsisOnSteroids::Errors::InvalidResponse.error(
        message: "Unexpected result: #{res}",
        response: data.fetch(:response)
      )
    end

    return res.fetch("Result")
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
    result = nil

    Timeout.timeout(300) do
      loop do
        sleep 1
        data = aos.req(url.path)
        res = data.fetch(:json)

        if res["State"] == "2"
          data_url = URI.parse(res.fetch("DataUrl"))
          result = aos.req_json(data_url.path)
          break
        elsif res["State"] == "0" || res["State"] == "1"
          # Keep waiting.
        else
          ApsisOnSteroids::Errors::InvalidState.error(
            message: "Unknown state: '#{res["State"]}': #{res}",
            response: data.fetch(:response)
          )
        end
      end
    end

    result.each do |element|
      raise "Unexpected result: '#{data}'." unless element["Value"] == "Succefully deleted"
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
