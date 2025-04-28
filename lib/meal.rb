require_relative 'nutrition_formatter.rb'

class Meal
  include NutritionFormatter

  attr_reader :id, :memo, :logged_at, :item_names, :items

  def initialize(id, memo, logged_at, calories, protein, item_names)
    @id = id
    @memo = memo
    @logged_at = logged_at
    @calories, @protein = calories, protein
    @item_names = item_names

    @items = []
  end

  def items=(meal_items)
    raise ArgumentError unless meal_items.all? { |item| item.is_a?(MealItem) }

    @items.push(*meal_items)
  end
end

# Meal Items
class MealItem
  include NutritionFormatter

  attr_reader :name, :serving_size

  def initialize(food_id, name, serving__size, calories, protein)
    @food_id = food_id
    @name = name
    @serving_size = serving__size
    @calories, @protein = calories, protein
  end

  # serving size format
end