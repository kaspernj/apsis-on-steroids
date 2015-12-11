class ApsisOnSteroids::Click < ApsisOnSteroids::SubBase
  def subscriber
    aos.subscriber_by_email(data(:email))
  end
end
