# frozen_string_literal: true

require 'sinatra'
require 'sinatra/contrib'
require 'date_core'
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

helpers do
  # DateTime Formatting
  def format_datetime(datetime)
    "#{format_date(datetime)} #{format_time(datetime)}"  
  end

  def format_datetime_input(datetime)
    time = datetime.strftime('%H:%M')
    "#{format_date(datetime)}T#{time}"
  end

  def format_date(datetime)
    # Year-Month-Day
    datetime.strftime('%Y-%m-%d')
  end

  def format_time(datetime)
    # Hour:Minute
    datetime.strftime('%l:%M%p').strip
  end

  def now
    format_datetime_input(DateTime.now)
  end

  # Nutrition Formatting
  def format_kcal(calories)
    "#{calories}kcal"
  end

  def format_protein(protein)
    "#{format_grams(protein)} protein"
  end

  def format_grams(value)
    "#{value}g"
  end

  # If a food option is selected (params[:food_id]), return that ID as an integer.
  # Otherwise return the food ID of the current meal item.
  def selected_food_id(params_food_id, meal_item_food_id)
    params_food_id ? params_food_id.to_i : meal_item_food_id
  end
end

# To Do:
# CRUD for foods database
# /new for creating new meals/meal_items

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
  load_meal(params[:meal_id])

  erb :edit_meal
end

# Update an individual meal
post '/meals/:meal_id/edit' do
  meal_id = params[:meal_id].to_i
  memo = params[:memo]
  logged_at = params[:logged_at]

  session[:error] = meal_update_error(meal_id, memo, logged_at)

  if session[:error]
    load_meal
    erb :edit_meal
  else
    @meal = @storage.update_and_return_meal(meal_id, memo, logged_at)
    session[:meal] = @meal
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
post '/meals/:meal_id/items' do
  meal_id = params[:meal_id].to_i
  food_id = params[:food_id].to_i
  serving_size = params[:serving_size].to_i

  session[:error] = meal_item_insert_error(meal_id, food_id, serving_size)

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

# (Form) Edit a meal item
get '/meals/:meal_id/items/:item_id/edit' do
  @item_id = params[:item_id].to_i
  load_meal_page_data(params[:meal_id])

  erb :meal
end

# Update a meal item
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

# Delete a meal item
post '/meals/:meal_id/items/:item_id/delete' do
  # Confirmation prompt via javascript
  item_id = params[:item_id]

  meal_item = @storage.load_meal_item(item_id)
  @storage.delete_meal_item(item_id)
  session[:success] = "#{meal_item.name} successfully removed."

  redirect "meals/#{params[:meal_id]}"
end

# # # # # Foods # # # # # 
# View all foods
get '/foods' do
  # paginate
  @foods = @storage.load_foods
  
  erb :foods
end

# (Form): Add a new food
get '/foods/new' do
  erb :new_food
end

# Add a new food
post '/foods' do
  binding.pry
  name = params[:name]
  standard_portion = params[:standard_portion].to_f
  calories = params[:calories].to_f
  protein = params[:protein].to_f

  session[:error] = food_insert_error(name, standard_portion, calories, protein)

  if session[:error]
    erb :new_food
  else
    food = @storage.create_and_return_food(name, standard_portion, calories, protein)
    session[:success] = "Successfully added #{food.name} to the database!"
    
    redirect "/foods/#{food.id}"
  end
end


# View a specific food
get '/foods/:food_id' do
  @food = @storage.load_food(params[:food_id])

  erb :food
end






##################
# Helper Methods #
##################
def load_meal(meal_id)
  @meal = session.delete(:meal) || @storage.load_meal(meal_id)
  redirect_if_nil(@meal)

  @meal
end

# Load all data for an individual meal page.
def load_meal_page_data(meal_id)
  load_meal(meal_id)
  @meal.items = @storage.load_meal_items_by_meal(meal_id)
  @food_options = load_food_options
end

def load_food_options
  @storage.load_foods
end

def redirect_if_nil(meal)
  if meal.nil?
    session[:error] = "That meal doesn't seem to exist."
    redirect '/'
  end
end

# # Error Message Methods
# Generic
def range_error(attr_name, value, min: nil, max: nil)
  error_message = "#{attr_name} must be #{range_error_descriptor(min: min, max: max)}."
  
  error_message unless (min..max).cover?(value)
end

def range_error_descriptor(min: nil, max: nil)
  if min && max
    "between #{min} and #{max}"
  elsif min
    "greater than #{min}"
  elsif max
    "less than #{max}"
  end
end

# Meals
def meal_insert_error(memo, logged_at)
  if empty?(memo)
    'Memo (description) cannot be empty.'
  elsif empty?(logged_at)
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
def food_insert_error(name, standard_portion, calories, protein)
  ten_digit_max = 99999999.99

  ('Name cannot be empty.' if empty?(name)) ||
    food_collision_error(name) ||
    range_error('Standard Portion', standard_portion, min: 1, max: ten_digit_max) ||
    range_error('Calories', calories, min: 1, max: ten_digit_max) ||
    range_error('Protein', protein, min: 1, max: ten_digit_max)
end

def null_food_error(food_id)
  if food_is_null?(food_id)
    <<~HEREDOC
      That food (id = #{food_id}) was not found.
      Try adding it to the database?
    HEREDOC
  end
end

def food_collision_error(name) 
  unless @storage.unique_food_name?(name)
    "There is already another item named #{name} in the database."
  end
end


# Meal Items
def meal_item_insert_error(meal_id, food_id, serving_size)
  serving_size_error(serving_size) ||
    meal_item_collision_error(meal_id: meal_id, food_id: food_id) ||
    null_meal_error(meal_id) ||
    null_food_error(food_id)
end

def meal_item_update_error(id, meal_id, new_food_id, new_serving_size)
  serving_size_error(new_serving_size) ||
    meal_item_collision_error(id: id, meal_id: meal_id, food_id: new_food_id) ||
    null_food_error(new_food_id)
end

def meal_item_collision_error(id: nil, meal_id: nil, food_id: nil)
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
def empty?(str)
  str.strip.empty?
end

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
