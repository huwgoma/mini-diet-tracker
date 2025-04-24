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
    session[:meal] = meal
    redirect "/meals/#{meal.id}"
  else
    session[:error] = "Bad meal"
    erb :new_meal
  end
end

# View a specific meal
get '/meals/:meal_id' do
  @meal = session.delete(:meal) || @storage.find_meal(params[:meal_id])
  @foods = @storage.load_food_names
  # If redirecting from meal creation, pass the meal object through the redirect via sess
  # otherwise, query for the meal via id.
  erb :meal
end

# Add a food item to a meal
post 'meals/:meal_id/foods' do
  # How to insert records into meals_foods without food_id?
  # Possible refactor:
  # - Represent food items as Food objects.
  # - That way the id is accessible within the application
end


##################
# Helper Methods #
##################
def valid_meal?(memo, logged_at)
  memo.size > 0 && logged_at.size > 0
  # Return true if meal is valid - ie. memo and timestamp are both present
  # false otherwise

end