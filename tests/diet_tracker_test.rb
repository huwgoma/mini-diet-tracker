ENV['RACK_ENV'] = 'test'

require 'minitest/reporters'
Minitest::Reporters.use!
require 'minitest/autorun'
require 'rack/test'

require_relative '../diet_tracker'

class DietTrackerTest < Minitest::Test
  include Rack::Test::Methods 

  def app
    Sinatra::Application
  end
end
