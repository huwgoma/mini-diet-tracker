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
  redirect '/dashboard'
end

# Dashboard (Home Page)
get '/dashboard' do
  @date = params[:date] || Date.today.to_s
  @meals = @storage.meals(@date)

  erb :home
end

# Create a new meal
get '/meals/new' do
  erb :new_meal
end

post '/meals' do
  if valid_meal?(params[:memo], params[:logged_at])
    meal = @storage.create_meal(params[:memo], params[:logged_at])
    
    # db creates new meal entry 
    # how to pull id? 
    redirect "/meals/#{meal.id}"
    # create meal
    # redirect "meal/#{params meal_id}"
  else
    session[:error] = "Bad meal"
    erb :new_meal
  end
  # Validate meal
  # Create if valid 
  # if not valid, re-render 
  # If valid, create -> redirect to meal
  # Where user can then add foods
end


##################
# Helper Methods #
##################
def valid_meal?(memo, logged_at)
  memo.size > 0 && logged_at.size > 0
  # Return true if meal is valid - ie. memo and timestamp are both present
  # false otherwise

end