require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "ApsisOnSteroids" do
  let(:aos) do
    ApsisOnSteroids.new(
      :api_key => File.read("#{File.dirname(__FILE__)}/api_key.txt").strip,
      :debug => false
    )
  end

  it "can connect" do
    aos
  end
  
  it "should create and delete a mailing list" do
    name = "create-mlist-#{Time.now.to_f.to_s}"
    
    aos.create_mailing_list(
      :Name => name,
      :FromName => "Kasper Johansen",
      :FromEmail => "kj@naoshi-dev.com",
      :CharacterSet => "utf-8"
    )
    
    mlist = aos.mailing_list_by_name(name)
    
    sleep 1
    mlist.delete
  end

  it "can get a mailing list" do
    aos.mailing_list_by_name("kj")
  end

  context do
    let(:mlist) { aos.mailing_list_by_name("kj") }
    let(:sub) do
      email = "kaspernj#{Time.now.to_f}@naoshi-dev.com"
      mlist.create_subscribers([{
        :Email => email,
        :Name => "Kasper Johansen"
      }])
      aos.subscriber_by_email(email)
    end
  
    it "can create subscribers" do
      sub
    end

    it "can get subscribers and their details" do
      details = sub.details
      details.is_a?(Hash).should eql(true)
      details.key?(:pending).should eql(false)
    end

    it "can update subscribers" do
      new_email = "kaspernj#{Time.now.to_f}-updated@naoshi-dev.com"
      sub.update(:Email => new_email)
      sleep 1
      sub.details[:Email].should eql(new_email)
      sub.details[:Name].should eql("Kasper Johansen")
    end

    it "should not overwrite data when updating" do
      phone = Time.now.to_i.to_s
      sub.update(:PhoneNumber => phone)
      sub.details[:PhoneNumber].should eql(phone)

      new_email = "kaspernj#{Time.now.to_f}-updated@naoshi-dev.com"
      sub.update(:Email => new_email)
      sub.details[:Email].should eql(new_email)

      sub.details[:PhoneNumber].should eql(phone)
    end

    it "can remove subscribers from lists" do
      mlist.remove_subscriber(sub)
    end

    it "can get lists of subscribers from lists" do # err
      mlist.subscribers do |sub|
        puts "Subscriber: #{sub}"
      end
    end

    it "can validate if a subscriber is active or not" do
      sub.active?.should eql(true)
    end

    it "can get a list of all subscribers" do # should not be run each time - will end up being rather big!
      total_list = aos.subscribers
      total_list.is_a?(Array).should eql(true)
    end
  end
end
