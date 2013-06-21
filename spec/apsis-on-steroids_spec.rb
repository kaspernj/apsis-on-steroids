require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "ApsisOnSteroids" do
  it "can connect" do
    $aos = ApsisOnSteroids.new(
      :api_key => File.read("#{File.dirname(__FILE__)}/api_key.txt").strip,
      :debug => false
    )
  end
  
  it "should create and delete a mailing list" do
    name = "create-mlist-#{Time.now.to_f.to_s}"
    
    $aos.create_mailing_list(
      :Name => name,
      :FromName => "Kasper Johansen",
      :FromEmail => "kj@naoshi-dev.com",
      :CharacterSet => "utf-8"
    )
    
    mlist = $aos.mailing_list_by_name(name)
    
    sleep 1
    mlist.delete
  end
  
  it "can get a mailing list" do
    $mlist = $aos.mailing_list_by_name("kj")
  end
  
  it "can create subscribers" do
    $mlist.create_subscribers([{
      :Email => "kj@gfish.com",
      :Name => "Kasper Johansen"
    }])
  end
  
  it "can get subscribers and their details" do
    $sub = $aos.subscriber_by_email("kj@gfish.com")
    details = $sub.details
    details.is_a?(Hash).should eql(true)
    details.key?(:pending).should eql(false)
  end
  
  it "can update subscribers" do
    new_email = "kaspernj#{Time.now.to_f}@naoshi-dev.com"
    $sub.update(:Email => new_email)
    $sub.details[:Email].should eql(new_email)
    $sub.details[:Name].should eql("Kasper Johansen")
  end
  
  it "should not overwrite data when updating" do
    phone = Time.now.to_i.to_s
    $sub.update(:PhoneNumber => phone)
    $sub.details[:PhoneNumber].should eql(phone)
    
    new_email = "kaspernj#{Time.now.to_f}@naoshi-dev.com"
    $sub.update(:Email => new_email)
    $sub.details[:Email].should eql(new_email)
    
    $sub.details[:PhoneNumber].should eql(phone)
  end
  
  it "can remove subscribers from lists" do
    $mlist.remove_subscriber($sub)
  end
  
  it "can get lists of subscribers from lists" do
    $mlist.subscribers do |sub|
      puts "Subscriber: #{sub}"
    end
  end
  
  it "can validate if a subscriber is active or not" do
    $sub.active?.should eql(true)
  end
  
  it "can get a list of all subscribers" do
    total_list = $aos.subscribers
    total_list.is_a?(Array).should eql(true)
  end
end
