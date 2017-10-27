require 'pg'

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
      PG.connect(ENV['DATABASE_URL'])
    else
      PG.connect(dbname: "easybudget")
    end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def get_monthly_income
    sql = ("SELECT amount FROM income")
    result = query(sql)

    result.map { |tuple| tuple["amount"]}.first
  end

  def update_monthly_income(amount)
    sql = ("UPDATE income SET amount = $1")
    query(sql, amount)
  end

  def get_all_purchases
    sql = <<~SQL 
      SELECT purchases.id, categories.name AS category_name, purchases.date, purchases.amount 
      FROM purchases JOIN categories ON purchases.category_id = categories.id
    SQL
    purchases = query(sql)

    purchases.map do |tuple|
      { id: tuple["id"], 
        category: tuple["category_name"], 
        date: tuple["date"], 
        amount: tuple["amount"]
      }
    end
  end

  def get_all_categories
    result = query("SELECT * FROM categories")

    result.map do |tuple|
      { id: tuple["id"],
        name: tuple["name"],
        amount: tuple["amount"]
      }
    end
  end

  def save_category(category_name, amount)
    sql = ("INSERT INTO categories (name, amount) VALUES ($1, $2)")
    query(sql, category_name, amount)
  end

  def update_category(category_name, category_amount, category_id)
    sql = ("UPDATE categories SET name = $1, amount = $2 WHERE id = $3")
    query(sql, category_name, category_amount, category_id)
  end

  def delete_category(category_id)
    sql = ("DELETE FROM categories WHERE id = $1")
    query(sql, category_id)
  end

  def get_all_purchases_by_category(category_id)
    sql = ("SELECT * FROM purchases WHERE category_id = $1")
    result = query(sql, category_id)
  end

  def get_single_purchase(purchase_id)
    sql = ("SELECT * FROM purchases WHERE id = $1")
    query(sql, purchase_id)
  end

  def save_purchase(category_id, date, amount)
    sql = ("INSERT INTO purchases (category_id, date, amount) VALUES ($1, $2, $3)")
    query(sql, category_id, date, amount)
  end

  def update_single_purchase(category, amount, purchase_id)
    sql = ("UPDATE purchases SET category = $1, amount = $2 WHERE id = $3")
    query(sql, category, amount, purchase_id)
  end

  def delete_purchase(purchase_id)
    sql = ("DELETE FROM purchases WHERE id = $1")
    query(sql, purchase_id)
  end

  
end