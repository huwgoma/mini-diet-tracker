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

  def meals
    sql = "SELECT * FROM meals;"
    meals = query(sql)

    meals.map do |meal|
      id = meal['id'].to_i
      memo = meal['memo']
      logged_at = meal['logged_at']

      Meal.new(id, memo, logged_at)
    end
  end
end