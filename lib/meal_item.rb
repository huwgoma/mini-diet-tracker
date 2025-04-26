class MealItem
  def initialize(food_id, name, serving_size, calories, protein)
    @food_id, @name, @serving_size = food_id, name, serving_size
    @calories, @protein = calories, protein
  end
end