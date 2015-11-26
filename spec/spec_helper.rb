if ENV['CODECLIMATE_REPO_TOKEN']
  # This must be the very first thing in spec_helper!
  require 'codeclimate-test-reporter'
  CodeClimate::TestReporter.start
end

ENV['RAILS_ENV'] ||= 'test'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'apsis-on-steroids'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  
end
