class Meal
  attr_reader :memo, :logged_at, :foods

  def initialize(id, memo, logged_at, foods, calories, protein)
    @id = id
    @memo = memo
    @logged_at = logged_at
    @foods = foods
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