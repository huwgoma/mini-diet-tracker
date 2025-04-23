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

  def meals(date)
    sql = "SELECT * FROM meals WHERE logged_at::date = $1;"
    meals = query(sql, date)

    meals.map { |meal| format_meal(meal) }
  end

  private
  
  def format_meal(meal)
    id = meal['id'].to_i
    memo = meal['memo']
    logged_at = meal['logged_at']

    Meal.new(id, memo, logged_at)
  end
end