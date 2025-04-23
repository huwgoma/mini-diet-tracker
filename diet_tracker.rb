# frozen_string_literal: true

require 'sinatra'
require 'sinatra/contrib'

require 'pry'

require_relative 'database_adapter'
require_relative 'lib/meal'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)

  set :erb, :escape_html => true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'database_adapter.rb', 'lib/meal.rb'
end

before do
  @storage = DatabaseAdapter.new(logger)
end

# Home Page
get '/' do
  @meals = @storage.meals

  erb :home
end


# Meal Object
# - stores the @memo and @logged_at info