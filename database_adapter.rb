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

  # # # # # # # Meals # # # # # # #
  # Retrieve all meals by date
  def load_meals_by_date(date)
    sql = <<~SQL
      SELECT meals.id, meals.memo, meals.logged_at, 
        STRING_AGG(foods.name, ', ') AS meal_item_names,
        SUM(ADJUST(calories, serving_size, standard_portion)) AS total_calories,
        SUM(ADJUST(protein, serving_size, standard_portion)) AS total_protein
      FROM meals 
        LEFT JOIN meal_items ON meals.id = meal_id
        LEFT JOIN foods       ON foods.id = food_id
      WHERE meals.logged_at::date = $1
      GROUP BY meals.id;
    SQL

    meals = query(sql, date)
    meals.map { |meal| format_meal(meal) }
  end

  # Retrieve single meal by ID
  def load_meal(id)
    sql = <<~SQL
      SELECT meals.id, meals.memo, meals.logged_at, 
        STRING_AGG(foods.name, ', ') AS meal_item_names,
        SUM(ADJUST(calories, serving_size, standard_portion)) AS total_calories,
        SUM(ADJUST(protein, serving_size, standard_portion)) AS total_protein
      FROM meals 
        LEFT JOIN meal_items ON meals.id = meal_id
        LEFT JOIN foods      ON foods.id = food_id
      WHERE meals.id = $1
      GROUP BY meals.id;
    SQL
    result = query(sql, id)

    format_meal(result.first)
  end

   # Insert new meal
  def create_and_return_meal(memo, logged_at)
    sql = "INSERT INTO meals (memo, logged_at)
           VALUES($1, $2)
           RETURNING *;"
    result = query(sql, memo, logged_at)

    format_meal(result.first)
  end

  # Update existing meal
  def update_and_return_meal(id, memo, logged_at)
    sql = "UPDATE meals SET
           memo = $2, logged_at = $3
           WHERE id = $1
           RETURNING *;"
    result = query(sql, id, memo, logged_at)

    format_meal(result.first)
  end

  def delete_meal(id)
    sql = "DELETE FROM meals WHERE id = $1;"
    query(sql, id)
  end

  # # # # # # # Foods # # # # # # #
  # Retrieve all foods 
  def load_foods
    sql = "SELECT * FROM foods;"
    result = query(sql)
    
    result.map { |food| format_food(food) }
  end

  # Retrieve a single food 
  def load_food(id)
    sql = "SELECT * FROM foods WHERE id = $1;"
    result = query(sql, id)

    format_food(result.first)
  end

  # Query whether there is ANOTHER record in foods with the same name
  # - If ID is given, ignore any records with the given ID.
  def unique_food_name?(name, id = nil)
    sql = "SELECT 1 FROM foods
           WHERE LOWER(name) = $1 
           AND ($2::integer IS NULL OR id <> $2);"
    result = query(sql, name.downcase, id)

    result.none?
  end

  # Insert a new record into foods and return the resulting record
  def create_and_return_food(name, standard_portion, calories, protein)
    sql = "INSERT INTO foods (name, standard_portion, calories, protein)
           VALUES($1, $2, $3, $4)
           RETURNING *;"
    result = query(sql, name, standard_portion, calories, protein)

    format_food(result.first)
  end

  # Update a food 
  def update_food(id, name, standard_portion, calories, protein)
    sql = "UPDATE foods SET
           name = $2, standard_portion = $3, 
           calories = $4, protein = $5
           WHERE id = $1;"
    query(sql, id, name, standard_portion, calories, protein)
  end

  def delete_food(id)
    sql = "DELETE FROM foods
           WHERE id = $1;"
    query(sql, id)
  end

  # # # # # # Meal Items # # # # # 
  # Check whether a meal_item record is unique, based on meal_id and food_id.
  # - If an id is given (ie. UPDATE), exclude any records with the same id.
  # - If an id is not given (ie. INSERT), do not exclude any records based on id.
  def unique_meal_item?(id: nil, meal_id: nil, food_id: nil)
    sql = "SELECT 1 FROM meal_items
           WHERE meal_id = $2 AND food_id = $3
           AND ($1::integer IS NULL OR id <> $1);"
    result = query(sql, id, meal_id, food_id)

    result.none?
  end 

  # Retrieve all meal items associated with the given meal ID
  def load_meal_items_by_meal(meal_id)
    sql = "SELECT meal_items.id, foods.id AS food_id, foods.name, 
            meal_items.serving_size,
            ADJUST(calories, serving_size, standard_portion) AS item_calories,
            ADJUST(protein, serving_size, standard_portion) AS item_protein
           FROM foods 
           JOIN meal_items ON foods.id = food_id
           WHERE meal_id = $1"
    result = query(sql, meal_id)

    result.map { |item| format_meal_item(item) }
  end

  # Retrieve a single meal item
  def load_meal_item(id)
    sql = "SELECT meal_items.id, foods.id AS food_id, foods.name,
            meal_items.serving_size,
            ADJUST(calories, serving_size, standard_portion) AS item_calories,
            ADJUST(protein, serving_size, standard_portion) AS item_protein
           FROM foods 
           JOIN meal_items ON foods.id = food_id
           WHERE meal_items.id = $1;"
    result = query(sql, id)

    format_meal_item(result.first)
  end
  
  # Create a new meal item
  def create_meal_item(meal_id, food_id, serving_size)
    sql = "INSERT INTO meal_items (meal_id, food_id, serving_size)
           VALUES($1, $2, $3)"
    query(sql, meal_id, food_id, serving_size)
  end

  # Update a meal item
  def update_meal_item(id, food_id, serving_size)
    sql = "UPDATE meal_items SET
           food_id = $2, serving_size = $3
           WHERE id = $1;"
    query(sql, id, food_id, serving_size)
  end

  # Delete a meal item
  def delete_meal_item(id)
    sql = "DELETE FROM meal_items
           WHERE id = $1;"
    query(sql, id)
  end

  private

  def format_meal(meal)
    return if meal.nil?
    
    id = meal['id'].to_i
    memo = meal['memo']
    logged_at = format_datetime(meal['logged_at'])
    calories = meal['total_calories'].to_f
    protein = meal['total_protein'].to_f
    meal_item_names = meal['meal_item_names']

    Meal.new(id, memo, logged_at, 
             calories, protein, meal_item_names)
  end

  def format_datetime(datetime)
    DateTime.parse(datetime)
  end

  def format_meal_item(item)
    return if item.nil?
    
    id = item['id'].to_i
    food_id = item['food_id'].to_i
    name = item['name']
    serving_size = item['serving_size'].to_f
    calories = item['item_calories'].to_f
    protein = item['item_protein'].to_f

    MealItem.new(id, food_id, name, serving_size, calories, protein)
  end

  def format_food(food)
    return if food.nil?
    
    id = food['id'].to_i
    name = food['name']
    standard_portion = food['standard_portion'].to_i
    calories = food['calories'].to_f
    protein = food['protein'].to_f

    Food.new(id, name, standard_portion, calories, protein)
  end
end