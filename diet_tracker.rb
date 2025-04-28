# frozen_string_literal: true

require 'sinatra'
require 'sinatra/contrib'

require 'pry'

require_relative 'database_adapter'
Dir.glob('lib/*.rb').each { |file| require_relative file }

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

# Edit an individual meal
get '/meals/:meal_id/edit' do
  @meal = @storage.load_meal(params[:meal_id])
  @meal.items = @storage.load_meal_items(params[:meal_id])

  erb :edit_meal
end

post '/meals/:meal_id/edit' do
  binding.pry
end

# Add a food item to a meal
post '/meals/:meal_id/foods' do
  meal_id = params[:meal_id].to_i
  food_id = params[:food_id].to_i
  serving_size = params[:serving_size].to_i

  session[:error] = meal_item_error(meal_id, food_id, serving_size)

  unless session[:error]
    # success message
    @storage.create_meal_item(meal_id, food_id, serving_size)
  end

  redirect "/meals/#{meal_id}"
  # refactor how to select meal items into a search bar
end


##################
# Helper Methods #
##################

## Validation Methods
def valid_meal?(memo, logged_at)
  memo.size > 0 && logged_at.size > 0
end

def meal_item_error(meal_id, food_id, serving_size)
  if serving_size <= 0
    "Serving size must be greater than 0."
  elsif duplicate_meal_item?(meal_id, food_id)
    <<~HEREDOC
      You can't add the same food item twice to a meal.
      Try editing the existing food entry instead.
    HEREDOC
  elsif null_meal?(meal_id)
    "That meal (id = #{meal_id}) was not found."
  elsif null_food?(food_id)
    "That food (id = #{food_id}) was not found. Try adding it to the database."
  end
end

def duplicate_meal_item?(meal_id, food_id)
  @storage.meal_item_exists?(meal_id, food_id)
end

def null_meal?(meal_id)
  !@storage.load_meal(meal_id)
end

def null_food?(food_id)
  !@storage.load_food(food_id)
end
