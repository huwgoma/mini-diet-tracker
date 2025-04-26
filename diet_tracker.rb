# frozen_string_literal: true

require 'sinatra'
require 'sinatra/contrib'

require 'pry'

require_relative 'database_adapter'
require_relative 'lib/meal.rb'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)

  set :erb, :escape_html => true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'database_adapter.rb', 'lib/*.rb'
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
  @meals = @storage.load_meals(@date)

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
  @meal = session.delete(:meal) || @storage.load_meal(params[:meal_id])
  @meal.items = @storage.load_meal_items(params[:meal_id])

  @food_list = @storage.load_foods


  erb :meal
end

# Add a food item to a meal
post '/meals/:meal_id/foods' do
  meal_id = params[:meal_id].to_i
  food_id = params[:food_id].to_i
  serving_size = params[:serving_size].to_i

  if valid_meal_item?(meal_id, food_id, serving_size)
    @storage.add_food_to_meal(meal_id, food_id, serving_size)
    binding.pry
    # insert new record into meals_items
    # success!
    # redirect to same meal page 
  else
    # error!
    # re-render same meal page.
  end

end


##################
# Helper Methods #
##################
def valid_meal?(memo, logged_at)
  memo.size > 0 && logged_at.size > 0
end

def valid_meal_item?(meal_id, food_id, serving_size)
  serving_size.positive? &&
    @storage.load_meal(meal_id) &&
    @storage.find_food(food_id) &&
    !@storage.meal_item_exists?(meal_id, food_id)
end