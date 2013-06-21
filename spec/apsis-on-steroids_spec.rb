require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "ApsisOnSteroids" do
  it "can connect" do
    $aos = ApsisOnSteroids.new(
      :api_key => File.read("#{File.dirname(__FILE__)}/api_key.txt").strip,
      :debug => false
    )
  end
  
  it "can get a mailing list" do
    $mlist = $aos.mailing_list_by_name("kj")
  end
  
  it "can create subscribers" do
    $mlist.create_subscribers([{
      "Email" => "kj@gfish.com",
      "Name" => "Kasper Johansen"
    }])
  end
  
  it "can get subscribers and their details" do
    $sub = $aos.subscriber_by_email("kj@gfish.com")
    details = $sub.details
    details.is_a?(Hash).should eql(true)
    details.key?(:pending).should eql(true)
  end
  
  it "can update subscribers" do
    new_email = "kaspernj#{Time.now.to_f}@naoshi-dev.com"
    $sub.update(:Email => new_email)
    $sub.details[:Email].should eql(new_email)
  end
  
  it "should not overwrite data when updating" do
    addr = Time.now.to_f.to_s
    $sub.update(:Address => addr)
    
    new_email = "kaspernj#{Time.now.to_f}@naoshi-dev.com"
    $sub.update(:Email => new_email)
    
    $sub.details[:Address].should eql(addr)
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
