class Food
  attr_reader :id, :name, :standard_portion, :calories, :protein
  
  def initialize(id, name, standard_portion, calories, protein)
    @id, @name = id, name
    @standard_portion = standard_portion
    @calories, @protein = calories, protein
  end
end