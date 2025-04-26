class Meal
  attr_reader :id, :memo, :logged_at, :item_names

  def initialize(id, memo, logged_at, 
                 calories, protein, item_names)
    @id, @memo, @logged_at = id, memo, logged_at
    @calories, @protein = calories, protein

    @item_names = item_names
  end

  def protein
    "#{@protein}g"
  end

  def calories
    "#{@calories} kcal"
  end
end