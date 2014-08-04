class ApsisOnSteroids::Sending < ApsisOnSteroids::SubBase
  def clicks args = {}
    list_for("v1/clicks/sendqueues/%{send_queue_id}/page/%{page}/size/%{size}", "Click", args)
  end

  def opens args = {}
    list_for("v1/opens/sendqueues/%{send_queue_id}/page/%{page}/size/%{size}", "Open", args)
  end

  def bounces args = {}
    list_for("v1/bounces/sendqueues/%{send_queue_id}/page/%{page}/size/%{size}", "Bounce", args)
  end

  def opt_outs args = {}
    list_for("v1/optouts/sendqueues/%{send_queue_id}/%{page}/%{size}", "OptOut", args)
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

  def list_for resource_url, resource_name, args = {}
    page = 1
    resource_url = resource_url.gsub("%{send_queue_id}", data(:send_queue_id).to_s)

    if args[:count]
      resource_url = resource_url.gsub("%{page}", page.to_s).gsub("%{size}", "2")
      res = aos.req_json("/#{resource_url}")
      return res["Result"]["TotalCount"]
    end

    response_url = response_url.gsub("%{size}", "200")

    Enumerator.new do |yielder|
      loop do
        resource_url = resource_url.gsub("%{page}", page.to_s)
        res = aos.req_json("/#{resource_url}")

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
