require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "ApsisOnSteroids" do
  it "can connect" do
    aos = ApsisOnSteroids.new(:api_key => File.read("#{File.dirname(__FILE__)}/api_key.txt").strip)
    
    mlist = aos.mailing_list_by_name("kj")
    
    mlist.create_subscriber(
      "Email" => "kj@gfish.com",
      "Name" => "Kasper Johansen"
    )
    
    puts "Mailing list name: '#{mlist.name}'."
    
    subscribers = mlist.subscribers
    
    puts "Subscribers: #{subscribers}"
  end
end
