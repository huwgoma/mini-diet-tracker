module NutritionFormatter
  def grams(value)
    "#{value}g"  
  end

  def protein
    "#{grams(@protein)} Protein"   
  end

  def calories
    "#{@calories}kcal"  
  end
end