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

# # # # # # Meals # # # # # 
# Create a new meal
get '/meals/new' do
  erb :new_meal
end

post '/meals' do
  memo, logged_at = params[:memo], params[:logged_at]

  session[:error] = meal_data_error(memo, logged_at)

  if session[:error]
    erb :new_meal
  else 
    meal = @storage.create_and_return_meal(memo, logged_at)
    session[:meal] = meal
    redirect "/meals/#{meal.id}"
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
  meal_id = params[:meal_id].to_i
  memo, logged_at = params[:memo], params[:logged_at]

  session[:error] = meal_update_error(memo, logged_at, meal_id)

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
    @meal = session.delete(:meal) || @storage.load_meal(params[:meal_id])
    @meal.items = @storage.load_meal_items(params[:meal_id])
    @food_list = @storage.load_foods

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
  @meal = session.delete(:meal) || @storage.load_meal(params[:meal_id])
  @meal.items = @storage.load_meal_items(params[:meal_id])
  @item_id = params[:item_id].to_i
  
  @food_list = @storage.load_foods

  erb :meal
end

post '/meals/:meal_id/items/:item_id/edit' do
  item_id = params[:item_id].to_i
  meal_id = params[:meal_id].to_i
  food_id = params[:food_id].to_i
  serving_size = params[:serving_size].to_i
  
  session[:error] = meal_item_update_error(item_id, meal_id, food_id, serving_size)
  
  if session[:error]
    @meal = session.delete(:meal) || @storage.load_meal(params[:meal_id])
    @meal.items = @storage.load_meal_items(params[:meal_id])
    @item_id = params[:item_id].to_i
    
    @food_list = @storage.load_foods

    erb :meal
  else
    binding.pry
  end
  # Validate the updated meal item data
  # If error, re-render meal page (with item_id)
  # If successful, make the update
  # @storage.update_meal_item(id, meal_id, food_id, serving_size)
end

def meal_item_update_error(id, meal_id, new_food_id, new_serving_size)
  # Error if...
  # There is a collision
  meal_item_collision_error(id, meal_id, new_food_id)
end

def meal_item_collision_error(id, meal_id, food_id)
  unless @storage.unique_meal_item?(id: id, meal_id: meal_id, food_id: food_id)
    <<~HEREDOC
      You can't add the same food twice to the same meal.
      Try editing the existing food entry instead.
    HEREDOC
  end
  # Returns an error message if there is a 'collision' of meal items
  # during INSERT or UPDATE
  # - ie. A collision means there is another record in meal_items
  #       with the same meal_id and food_id.
  # - Edge Case:
  #   - If creating a record, we only want to check for meal_id 
  #     and food_id collision (id will be nil at the time of check)
  #   - If updating a record, we want to check for meal_id and food_id
  #     collisions among all records not including the record being
  #     updated.
  # - Input: id, meal_id, food_id
  #   - id may be nil (if creating a new meal_item record)
  # - Output: String if there is a collision error ('You cant add the
  #   same food twice to the same meal.'')
  #   
  # - Algorithm: Given 2 integers, meal_id and food_id, and optionally
  #   a 3rd integer, id:

  #   SELECT 1 FROM meal_items WHERE 
  #   meal_id = $1 AND food_id = $2
 
  #   - If ID is given, filter out any records that share the same id
  #   AND id <> $3
  #   - If ID is not given (id = NULL), do not filter out any records
  #   
  # $3 = id
  #   meal_id = $1 AND food_id = $2 AND ($3 IS NULL OR id <> $3)
end
##################
# Helper Methods #
##################

## Error Message Methods
def meal_data_error(memo, logged_at)
  if memo.strip.empty?
    'Memo (description) cannot be empty.'
  elsif logged_at.strip.empty?
    'You must provide a date and time for this meal.'
  end
end

def meal_update_error(memo, logged_at, meal_id)
  meal_data_error(memo, logged_at) || null_meal_error(meal_id)
end

def meal_item_error(meal_id, food_id, serving_size)
  serving_size_error(serving_size) ||
  # meal_item_collision_error(meal_id, food_id)
  # - load_meal_items(meal_id, food_id)
    duplicate_meal_item_error(meal_id, food_id) ||
    null_meal_error(meal_id) || null_food_error(food_id)
end

def null_meal_error(meal_id)
  "That meal (id = #{meal_id}) was not found." if meal_is_null?(meal_id)
end

def null_food_error(food_id)
  if food_is_null?(food_id)
    <<~HEREDOC
      That food (id = #{food_id}) was not found.
      Try adding it to the database?
    HEREDOC
  end
end

def null_meal_item_error(meal_item_id)
  "That item does not exist." unless meal_item_exists?(id: meal_item_id)
end

def serving_size_error(serving_size)
  "Serving size must be greater than 0." if serving_size <= 0
end

def duplicate_meal_item_error(meal_id, food_id)
  if meal_item_exists?(meal_id: meal_id, food_id: food_id)
    <<~HEREDOC
      You can't add the same food item twice to a meal.
      Try editing the existing food entry instead.
    HEREDOC
  end
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

def meal_item_exists?(id: nil, meal_id: nil, food_id: nil)
  @storage.meal_item_exists?(id: id, meal_id: meal_id, food_id: food_id)
end

def meal_item_is_null?(meal_item_id)
  !meal_item_exists?(id: meal_item_id)
end
