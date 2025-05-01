class Meal
  attr_reader :id, :memo, :item_names, :items, :logged_at, :calories, :protein

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
  attr_reader :id, :food_id, :name, :serving_size, :calories, :protein

  def initialize(id, food_id, name, serving_size, calories, protein)
    @id, @food_id = id, food_id
    @name = name
    @serving_size = serving_size
    @calories, @protein = calories, protein
  end
end