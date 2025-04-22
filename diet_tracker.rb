# frozen_string_literal: true

require 'sinatra'
require 'sinatra/contrib'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

configure(:development) do
  require 'sinatra/reloader'
end

before do
  # storage = pgadapter
end

get '/' do
  'Hello world!'
end