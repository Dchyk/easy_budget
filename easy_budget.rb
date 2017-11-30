require 'yaml'
require 'sinatra'
require 'tilt/erubis'

require_relative 'database_persistence'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

def require_signed_in_user
  unless session[:username]
    session[:message] = 'You must be signed in to do that.'
    redirect "/"
  end
end

def require_signin
  if session[:username].nil?
    redirect "/users/signin"
  end
end

def load_credentials
  YAML.load_file(get_yaml_path("users.yaml"))
end

def get_data_path
  data_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data/", __FILE__)
  else
    File.expand_path("../data/", __FILE__)
  end
end

def get_yaml_path(filename)
  file_path = File.join(get_data_path, filename)
end

def load_yaml_file(filename)
  YAML.load_file(get_yaml_path(filename))
end

def format_money(number)
  number.to_f.round(2).to_s
end

def save_purchase(purchase)
  purchases = load_yaml_file("spending.yaml")
  
  if purchases.nil?
    purchases = []
  end

  purchases << purchase

  File.open(get_yaml_path("spending.yaml"), "w") do |file|
      file.write(purchases.to_yaml)
    end
end

def update_purchase(purchase, index)
  purchases = load_yaml_file("spending.yaml")

  purchases[index] = purchase

  File.open(get_yaml_path("spending.yaml"), "w") do |file|
      file.write(purchases.to_yaml)
    end
end

def delete_purchase(index)
  purchases = load_yaml_file("spending.yaml")

  purchases.delete_at(index)

  File.open(get_yaml_path("spending.yaml"), "w") do |file|
      file.write(purchases.to_yaml)
    end
end

def save_income(income)
  budget_file = load_yaml_file("budget.yaml")
  budget_file[:monthly_income] = income

  save_budget_data_to_yaml(budget_file)
end

def add_expense_category(category_name, amount)
  budget_file = load_yaml_file("budget.yaml")

  if budget_file[:categories].nil?
    budget_file[:categories] = { category_name => amount }
  else
    budget_file[:categories][category_name] = amount
  end

  save_budget_data_to_yaml(budget_file)
end

def save_budget_data_to_yaml(budget_data)
  File.open(get_yaml_path("budget.yaml"), "w") do |file|
      file.write(budget_data.to_yaml)
    end  
end

def invalid_number?(input)
  no_value?(input) || !valid_number?(input)
end

def valid_number?(input)
  input.match(/^\d*[.]\d{2}|\d*/)
end

def invalid_name?(input)
  no_value?(input) || input.match(/[^\w\s]/)
end

def no_value?(input)
  input.nil? || input.size == 0
end

def yyyy_mm_dd_formatted(date)
  date.match(/\d{4}\-\d{2}-\d{2}/)
end

def return_correct_date_format(date)
  dates = date.split("-")
  dates[1] + "/" + dates[2] + "/" + dates[0]
end

def valid_date?(date)
  date.match(/\b\d{1,2}\/\d{1,2}\/(\d{2}|\d{4})\b/)
end

def return_formatted_date(date)
  if yyyy_mm_dd_formatted(date)
    date = return_correct_date_format(date)
  end

  unless valid_date?(date)
    return todays_date
  end

  date
end

def more_than_one_category_exists?(budget)
  budget[:categories].size > 1
end

def category_already_exists?(category_name)
  budget = load_yaml_file("budget.yaml")
  budget[:categories].keys.map(&:downcase).include?(category_name.downcase)
end

helpers do
  def total_spending_in_one_category(purchases, category_name)
    category_purchases = purchases.select { |purchase| purchase[:category] == category_name }
    category_purchases.map { |purchase| purchase[:amount].to_f }.inject(&:+) || 0
  end

  def total_spending_in_all_categories(purchases)
    purchases.map { |purchase| purchase[:amount].to_f }.inject(&:+)
  end

  def total_money_budgeted
    budget = load_yaml_file("budget.yaml")


    budget[:categories].map { |_, amount| amount.to_f.round(2) }.inject(&:+) || 0.00
  end

  def money_available_to_budget
    budget_file = load_yaml_file("budget.yaml")
    budget_file[:monthly_income].to_f.round(2) - total_money_budgeted || 0
  end

  def monthly_income
    budget = load_yaml_file("budget.yaml")
    budget[:monthly_income].to_f.round(2)
  end

  #def over_budget?
  #  total_money_budgeted > monthly_income
  #end

  #def over_total_budget?
  #  total_spending_in_all_categories > money_available_to_budget
  #end

  #def category_over_budget?(category)
  #  spending in category > budgeted for that category
  #  spending = load_yaml_file("spending.yaml")
  #  budget = load_yaml_file("budget.yaml")
  #  budgeted_for_category = budget[:categories][category].to_f

  #  total_spending_in_one_category(purchases, category) > budgeted_for_category
  #end

  # def get_category_class(category)
  #   if category_over_budget?(category)
  #     "expense-category-warning"
  #   else
  #     "expense-category"
  #   end
  # end

  def todays_date
    date = Time.now
    "#{date.month}/#{date.day}/#{date.year}"
  end

  def categories_exist?(budget)
    budget[:categories].keys.size > 0
  end

  def display_as_money(number)
    # Account for nil input and convert to 0
    number = 0.00 unless number
    sprintf("%.2f", number)
  end
end

before do
  @storage = DatabasePersistence.new(logger)
end

after do
  @storage.disconnect
end

get "/" do
  require_signin

  @income = @storage.get_monthly_income
  @purchases = @storage.get_all_purchases
  @categories = @storage.get_all_categories

  erb :index
end

not_found do
  session[:message] = "That page doesn't exist."
  redirect "/"
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do 
  username = params[:username]
  password = params[:password]

  users = load_credentials

  if users[username] == password
    session[:username] = username
    session[:message]  = "Welcome, #{username}!"
    redirect "/"
  else
    session[:message] = "Invalid credentials."
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You've been signed out."
  redirect "/"
end

get "/budget/edit_income" do
  require_signed_in_user
  @income = @storage.get_monthly_income
  erb :edit_income
end

post "/budget/edit_income" do
  require_signed_in_user 

  monthly_income = params[:income].strip

  if invalid_number?(monthly_income)
    session[:message] = "Invalid number!"
    status 422
    redirect "/budget/edit_income"
  else
    @storage.update_monthly_income(monthly_income)
    session[:message] = "Income successfully recorded."
    redirect "/"
  end
end

get "/budget/add_category" do
  require_signed_in_user
  erb :add_category
end

post "/budget/add_category" do
  require_signed_in_user

  category_name = params[:category_name].strip
  amount = params[:amount].strip

  if invalid_name?(category_name)
    session[:message] = "Invalid category name - only numbers and letters allowed!"
    erb :add_category
  elsif category_already_exists?(category_name)
    session[:message] = "Category name already exists - please choose a unique name!"
    erb :add_category
  elsif invalid_number?(amount)
    session[:message] = "Invalid number - please enter a positive number."
    erb :add_category
  else
    @storage.add_expense_category(category_name, amount)
    session[:message] = "#{category_name} category added to monthly expenses."
    redirect "/"
  end
end

get "/budget/:category_id/edit" do
  require_signed_in_user

  @category = @storage.get_all_categories.select { |tuple| tuple[:id] == params[:category_id] }.first

  erb :edit_category
end

post "/budget/:category_id/update" do
  require_signed_in_user

  existing_category_name = params[:category_name]
  new_category_name = params[:new_category_name]
  new_category_amount = format_money(params[:new_amount])

  if invalid_name?(new_category_name)
    session[:message] = "Invalid category name - must be text."
    redirect "/budget/#{params[:category_id]}/edit"
  end

  @storage.update_category(new_category_name, new_category_amount, params[:category_id])
  session[:message] = "#{new_category_name} category successfully updated!"
  redirect "/"
end

post "/budget/:category_id/delete" do
  require_signed_in_user

  # Prevent user-generated URLs to delete files
  #unless budget[:categories].include?(category_name)
  #  session[:message] = "Can't delete - that category doesn't exist!"
  #  redirect "/"
  #end

  @storage.delete_category(params[:category_id])

  session[:message] = "Category deleted."
  redirect "/"
end

get "/add_purchase" do
  require_signed_in_user

  @categories = @storage.get_all_categories 

  erb :add_purchase
end

post "/save_purchase" do
  require_signed_in_user

  date = return_formatted_date(params[:date])

  @storage.save_purchase(params[:category_id], date, params[:amount])

  session[:message] = "Purchase successfully recorded."
  redirect "/"
end

get "/budget/purchases/:purchase_id/edit" do
  require_signed_in_user

  @purchase = @storage.get_single_purchase(params[:purchase_id])
  @categories = @storage.get_all_categories

  erb :edit_purchase
end

post "/budget/purchases/:purchase_id/update" do
  require_signed_in_user

  if invalid_number?(params[:amount])
    session[:message] = "Invalid number!"
    status 422
    redirect "/budget/purchases/#{purchase_index}/edit"
  end

  category_id = params[:category_id]
  amount = params[:amount]
  date = params[:date]
  purchase_id = params[:purchase_id]

  @storage.update_single_purchase(category_id, amount, date, purchase_id)

  session[:message] = "Purchase successfully updated."
  redirect "/"
end

post "/budget/purchases/:purchase_id/delete" do
  require_signed_in_user

  @storage.delete_purchase(params[:purchase_id])

  session[:message] = "Purchase successfully deleted."
  redirect "/"
end

post "/budget/purchases/delete_all" do
  require_signed_in_user

  @storage.delete_all_purchases

  session[:message] = "All purchases have been successfully deleted. You're ready to start a fresh month!"
  redirect "/"
end