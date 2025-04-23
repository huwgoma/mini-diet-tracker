class Meal
  attr_reader :id, :memo, :logged_at, :foods

  def initialize(id, memo, logged_at, foods, calories, protein)
    @id = id
    @memo = memo
    @logged_at = logged_at
    @foods = foods.nil? ? [] : foods.split(', ')
    @calories = calories
    @protein = protein
  end

  def protein
    "#{@protein}g"
  end

  def calories
    "#{@calories} kcal"
  end
end