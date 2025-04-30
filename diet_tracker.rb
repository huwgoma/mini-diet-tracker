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

# To Do: 
# - Extract the loading of meal page data into a method
#   (to load: meal*, meal items, food list)
#   * 
# - Extract/Refactor meal.erb view components
# - Guard against nils

# Home Page - View all meals by date
get '/dashboard' do
  @date = params[:date] || Date.today.to_s
  @meals = @storage.load_meals_by_date(@date)

  erb :home
end

# # # # # Meals # # # # # 
# (Form): Create a new meal 
get '/meals/new' do
  erb :new_meal
end

# Create a new meal
post '/meals' do
  memo, logged_at = params[:memo], params[:logged_at]
  session[:error] = meal_insert_error(memo, logged_at)

  if session[:error]
    erb :new_meal
  else 
    meal = @storage.create_and_return_meal(memo, logged_at)
    session[:meal] = meal
    redirect "/meals/#{meal.id}"
  end
end

# View an individual meal
get '/meals/:meal_id' do
  load_meal_page_data(params[:meal_id])

  erb :meal
end

# (Form): Edit an individual meal
get '/meals/:meal_id/edit' do
  @meal = @storage.load_meal(params[:meal_id])

  erb :edit_meal
end

# Update an individual meal
post '/meals/:meal_id/edit' do
  meal_id = params[:meal_id].to_i
  
  memo = params[:memo]
  logged_at = params[:logged_at]

  # load meal regardless
  # if successful, pass meal through session

  session[:error] = meal_update_error(meal_id, memo, logged_at)

  if session[:error]
    @meal = @storage.load_meal(meal_id)

    erb :edit_meal
  else
    @storage.update_meal(meal_id, memo, logged_at)
    redirect "/meals/#{meal_id}"
  end
end

# Delete a meal
post '/meals/:meal_id/delete' do
  # Add confirmation prompt via javascript
  @storage.delete_meal(params[:meal_id])
  session[:success] = "Meal successfully deleted."
  
  redirect "/dashboard"
end

# # # # # # Meal Items # # # # # 
# Add an item to a meal
post '/meals/:meal_id/foods' do
  meal_id = params[:meal_id].to_i
  food_id = params[:food_id].to_i
  serving_size = params[:serving_size].to_i

  session[:error] = meal_item_error(meal_id, food_id, serving_size)

  if session[:error]
    load_meal_page_data(params[:meal_id])

    erb :meal
  else
    @storage.create_meal_item(meal_id, food_id, serving_size)
    session[:success] = "Food item added!"

    redirect "/meals/#{meal_id}"
  end
  # refactor how to select meal items into a search bar
end

# Edit a meal item
get '/meals/:meal_id/items/:item_id/edit' do
  @item_id = params[:item_id].to_i
  load_meal_page_data(params[:meal_id])

  erb :meal
end

post '/meals/:meal_id/items/:item_id/edit' do
  item_id = params[:item_id].to_i
  meal_id = params[:meal_id].to_i
  food_id = params[:food_id].to_i
  serving_size = params[:serving_size].to_i
  
  session[:error] = meal_item_update_error(item_id, meal_id, food_id, serving_size)
  
  if session[:error]
    @item_id = params[:item_id].to_i
    load_meal_page_data(params[:meal_id])

    erb :meal
  else
    @storage.update_meal_item(item_id, food_id, serving_size)
    redirect "/meals/#{meal_id}"
  end
end

##################
# Helper Methods #
##################

# Load all data for an individual meal page.
def load_meal_page_data(meal_id)
  @meal = session.delete(:meal) || @storage.load_meal(meal_id)
  @meal.items = @storage.load_meal_items(meal_id)
  @food_options = load_food_options
end

def load_food_options
  @storage.load_foods
end

# # Error Message Methods
# Meals
def meal_insert_error(memo, logged_at)
  if memo.strip.empty?
    'Memo (description) cannot be empty.'
  elsif logged_at.strip.empty?
    'You must provide a date and time for this meal.'
  end
end

def meal_update_error(meal_id, memo, logged_at)
  meal_insert_error(memo, logged_at) || null_meal_error(meal_id)
end

def null_meal_error(meal_id)
  "That meal (id = #{meal_id}) was not found." if meal_is_null?(meal_id)
end

# Food
def null_food_error(food_id)
  if food_is_null?(food_id)
    <<~HEREDOC
      That food (id = #{food_id}) was not found.
      Try adding it to the database?
    HEREDOC
  end
end

# Meal Items
def meal_item_insert_error(meal_id, food_id, serving_size)
  serving_size_error(serving_size) ||
    meal_item_collision_error(meal_id, food_id) ||
    null_meal_error(meal_id) ||
    null_food_error(food_id)
end

def meal_item_update_error(id, meal_id, new_food_id, new_serving_size)
  serving_size_error(new_serving_size) ||
    meal_item_collision_error(id, meal_id, new_food_id) ||
    null_food_error(new_food_id)
end

def meal_item_collision_error(id, meal_id, food_id)
  unless @storage.unique_meal_item?(id: id, meal_id: meal_id, food_id: food_id)
    <<~HEREDOC
      You can't add the same food twice to the same meal.
      Try editing the existing food entry instead.
    HEREDOC
  end
end

def serving_size_error(serving_size)
  "Serving size must be greater than 0." if serving_size <= 0
end

# Validation Condition Methods
def meal_exists?(meal_id)
  !!@storage.load_meal(meal_id)  
end

def meal_is_null?(meal_id)
  !meal_exists?(meal_id)
end

def food_exists?(food_id)
  !!@storage.load_food(food_id)
end

def food_is_null?(food_id)
  !food_exists?(food_id)
end
