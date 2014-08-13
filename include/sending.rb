class ApsisOnSteroids::Sending < ApsisOnSteroids::SubBase
  def clicks args = {}
    list_for("v1/clicks/sendqueues/%{send_queue_id}/page/%{page}/size/%{size}", "v1/sendqueues/%{send_queue_id}/clicks", "Click", args)
  end

  def opens args = {}
    list_for("v1/opens/sendqueues/%{send_queue_id}/page/%{page}/size/%{size}", "v1/sendqueues/%{send_queue_id}/opens", "Open", args)
  end

  def bounces args = {}
    list_for("v1/bounces/sendqueues/%{send_queue_id}/page/%{page}/size/%{size}", "v1/sendqueues/%{send_queue_id}/bounces", "Bounce", args)
  end

  def opt_outs args = {}
    list_for("v1/optouts/sendqueues/%{send_queue_id}/%{page}/%{size}", "v1/sendqueues/%{send_queue_id}/optouts", "OptOut", args)
  end

  def mailing_lists
    Enumerator.new do |yielder|
      data(:mailinglist_id).each do |mailing_list_id|
        next if mailing_list_id == 0
        yielder << aos.mailing_list_by_id(mailing_list_id)
      end
    end
  end

private

  def list_for_with_dates resource_url, resource_name, args
    resource_url = resource_url.gsub("%{send_queue_id}", data(:send_queue_id).to_s)

    ub = aos.new_url_builder
    ub.path = resource_url
    ub.params["dateFrom"] = args[:date_from].strftime(ApsisOnSteroids::STRFTIME_FORMAT) if args[:date_from]
    ub.params["dateTo"] = args[:date_to].strftime(ApsisOnSteroids::STRFTIME_FORMAT) if args[:date_to]

    resource_url = ub.build_path_and_params

    queued_res = aos.req_json(resource_url)
    results = aos.read_queued_response(queued_res["Result"]["PollURL"])

    return results.length if args[:count]

    Enumerator.new do |yielder|
      aos.read_resources_from_array(resource_name, results).each do |resource|
        yielder << resource
      end
    end
  end

  def list_for resource_url, resource_url_with_dates, resource_name, args = {}
    # OptOut counting does not work :-( We will have to do the date request to fix this...
    # If date-arguments are given, we will have to use the date request.
    if args[:date_from] || args[:date_to] || resource_name == "OptOut"
      return list_for_with_dates(resource_url_with_dates, resource_name, args)
    end

    page = 1
    resource_url = resource_url.gsub("%{send_queue_id}", data(:send_queue_id).to_s)

    if args[:count]
      resource_url = resource_url.gsub("%{page}", page.to_s).gsub("%{size}", "2")
      res = aos.req_json(resource_url)
      return res["Result"]["TotalCount"]
    end

    resource_url = resource_url.gsub("%{size}", "200")

    Enumerator.new do |yielder|
      loop do
        resource_url = resource_url.gsub("%{page}", page.to_s)
        res = aos.req_json(resource_url)

        aos.read_resources_from_array(resource_name, res["Result"]["Items"]).each do |resource|
          yielder << resource
        end

        size_no = res["Result"]["TotalPages"]
        if page >= size_no
          break
        else
          page += 1
        end
      end
    end
  end
end
