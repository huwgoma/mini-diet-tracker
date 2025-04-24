require 'pg'

class DatabaseAdapter
  attr_reader :db, :logger
  def initialize(logger)
    @db = PG.connect(dbname: 'diet')
    @logger = logger
  end

  def query(sql, *params)
    logger.info("#{sql}, #{params}")

    db.exec_params(sql, params)
  end

  # Retrieve all meals by date
  def meals(date)
    sql = <<~SQL
      SELECT meals.id, meals.memo, meals.logged_at, 
        STRING_AGG(foods.name, ', ') AS foods,
        SUM(ADJUSTED_NUTRITION(foods.calories, meals_items.serving_size, foods.standard_portion)) AS calories,
        SUM(ADJUSTED_NUTRITION(foods.protein, meals_items.serving_size, foods.standard_portion)) AS protein
      FROM meals 
        LEFT JOIN meals_items ON meals.id = meal_id
        LEFT JOIN foods       ON foods.id = food_id
      WHERE meals.logged_at::date = $1
      GROUP BY meals.id;
    SQL

    meals = query(sql, date)
    meals.map { |meal| format_meal(meal) }
  end

  # Retrieve single meal by ID
  def find_meal(id)
    sql = <<~SQL
      SELECT meals.id, meals.memo, meals.logged_at, 
        STRING_AGG(foods.name, ', ') AS foods,
        SUM(ADJUSTED_NUTRITION(foods.calories, meals_items.serving_size, foods.standard_portion)) AS calories,
        SUM(ADJUSTED_NUTRITION(foods.protein, meals_items.serving_size, foods.standard_portion)) AS protein
      FROM meals 
        LEFT JOIN meals_items ON meals.id = meal_id
        LEFT JOIN foods       ON foods.id = food_id
      WHERE meals.id = $1
      GROUP BY meals.id;
    SQL
    result = query(sql, id)

    format_meal(result.first)
  end

  # Insert new meal
  def create_meal(memo, logged_at)
    sql = "INSERT INTO meals (memo, logged_at)
           VALUES($1, $2)
           RETURNING *;"
    result = query(sql, memo, logged_at)

    format_meal(result.first)
  end

  # Load all food names
  def load_food_names
    sql = "SELECT name FROM foods;"
    result = query(sql)
    
    result.values.flatten
  end

  private

  def format_meal(meal)
    id = meal['id'].to_i
    memo = meal['memo']
    logged_at = meal['logged_at']
    foods = meal['foods']
    calories = meal['calories'].to_f
    protein = meal['protein'].to_f

    Meal.new(id, memo, logged_at, foods, calories, protein)
  end
end