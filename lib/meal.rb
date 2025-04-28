require_relative 'nutrition_formatter.rb'

class Meal
  include NutritionFormatter

  attr_reader :id, :memo, :item_names, :items

  def initialize(id, memo, logged_at, calories, protein, item_names)
    @id = id
    @memo = memo
    @logged_at = logged_at
    @calories, @protein = calories, protein
    @item_names = item_names

    @items = []
  end

  def datetime
    "#{date} #{time}"
  end

  def date
    # Year-Month-Day
    logged_at.strftime('%Y-%m-%d')
  end

  def time
    # Hour:Minute
    logged_at.strftime('%H:%M')
  end

  def items=(meal_items)
    raise ArgumentError unless meal_items.all? { |item| item.is_a?(MealItem) }

    @items.push(*meal_items)
  end

  private

  attr_reader :logged_at
end

# Meal Items
class MealItem
  include NutritionFormatter

  attr_reader :name, :serving_size

  def initialize(food_id, name, serving_size, calories, protein)
    @food_id = food_id
    @name = name
    @serving_size = serving_size
    @calories, @protein = calories, protein
  end

  def serving_size
    grams(@serving_size)
  end
end