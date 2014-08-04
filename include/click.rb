class ApsisOnSteroids::Click < ApsisOnSteroids::SubBase
  def subscriber
    return aos.subscriber_by_email(data(:email))
  end
end
