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

not_found do
  redirect '/dashboard/'
end

# Dashboard (Home Page)
get '/dashboard/:date?' do
  @date = params[:date] || Date.today.to_s

  @meals = @storage.meals(@date)
  
  # Optional Date
  # - If not given, defaults to today
  # Load the meals for the given day 
  # - Then display: calories for date, protein for date 
  #   Also: meals for date. For each meal:
  #   - Memo, Time logged, food items, meal cals, meal protein
  

  erb :home
end


# Meal Object
# - stores the @memo and @logged_at info