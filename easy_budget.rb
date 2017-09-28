require 'yaml'
require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'pry'

configure do
  enable :sessions
  set :session_secret, 'secret'
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
  no_value?(input) == 0 || input.match(/[^\w\s]/)
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
    date = return_correct_date_format
  end

  unless valid_date?(date)
    return todays_date
  end

  date
end

def validate_purchase
  # needed
end

def more_than_one_category_exists?(budget)
  budget[:categories].size > 1
end

helpers do
  def total_spending_in_one_category(category)
    spending = load_yaml_file("spending.yaml")
    category_spending = spending.select { |purchase| purchase[:category] == category }
    total = category_spending.map { |selected_purchase| selected_purchase[:amount].to_f.round(2) }.inject(&:+)
    total || 0.00
  end

  def total_spending_in_all_categories
    spending = load_yaml_file("spending.yaml")
    total_spending = spending.map { |purchase| purchase[:amount].to_f.round(2) }.inject(&:+)
    total_spending || 0.00
  end

  def total_money_budgeted
    budget = load_yaml_file("budget.yaml")

    budget[:categories].map { |_, amount| amount.to_f.round(2) }.inject(&:+) || 0.00
  end

  def money_available_to_budget
    budget_file = load_yaml_file("budget.yaml")
    budget_file[:monthly_income].to_f.round(2) - total_money_budgeted || 0
  end

  def over_budget?
    total_money_budgeted > money_available_to_budget
  end

  def over_total_budget?
    total_spending_in_all_categories > money_available_to_budget
  end

  def todays_date
    date = Time.now
    "#{date.month}/#{date.day}/#{date.year}"
  end

  def categories_exist?(budget)
    budget[:categories].keys.size > 0
  end

  def display_as_money(number)
    sprintf("%.2f", number)
  end
end

get "/" do
  require_signin

  @budget = load_yaml_file("budget.yaml")
  @purchases = load_yaml_file("spending.yaml")
  erb :index
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

get "/add_purchase" do
  require_signed_in_user

  @budget = load_yaml_file("budget.yaml") 

  erb :add_spending
end

post "/save_purchase" do
  date = return_formatted_date(params[:date])

  purchase = { category: params[:category],
               date:     date,
               amount:   format_money(params[:amount])
             }

  save_purchase(purchase)
  session[:message] = "Purchase successfully recorded."
  redirect "/"
end

get "/budget/edit_income" do
  @budget = load_yaml_file("budget.yaml")
  erb :edit_income
end

post "/budget/edit_income" do 
  monthly_income = params[:income].strip


  if invalid_number?(monthly_income)
    session[:message] = "Invalid number!"
    status 422
    redirect "/budget/edit_income"
  else
    format_money(monthly_income)
    save_income(monthly_income)
    
    session[:message] = "Income successfully recorded."
    redirect "/"
  end
end

get "/budget/edit_income" do
  @budget = load_yaml_file("budget.yaml")
  erb :edit_income
end

get "/budget/add_category" do
  erb :add_category
end

post "/budget/add_category" do
  category_name = params[:category_name].strip
  amount = params[:amount].strip

  if invalid_number?(amount)
    session[:message] = "Invalid number - please enter a positive number."
    erb :add_category
  elsif invalid_name?(category_name)
    session[:message] = "Invalid category name - only numbers and letters allowed!"
    erb :add_category
  else
    format_money(amount)
    add_expense_category(category_name, amount)
    session[:message] = "#{category_name} category added to monthly expenses."
    redirect "/"
  end
end

get "/budget/:category_name/edit" do
  @budget = load_yaml_file("budget.yaml")

  @category_name = params[:category_name]

  erb :edit_category
end

post "/budget/:category_name/update" do
  # Retain the existing category name in case only the amount is being updated
  existing_category_name = params[:category_name]
  new_category_name = params[:new_category_name]
  new_category_amount = format_money(params[:new_amount])

  if invalid_name?(new_category_name)
    session[:message] = "Invalid category name - must be text."
    redirect "/budget/#{existing_category_name}/edit"
  end

  budget = load_yaml_file("budget.yaml")

  if new_category_name == existing_category_name
    budget[:categories][existing_category_name] = new_category_amount
    session[:message] = "#{existing_category_name} successfully updated!"
  else
    budget[:categories].delete(existing_category_name)
    budget[:categories][new_category_name] = new_category_amount
    session[:message] = "#{new_category_name} successfully updated!"
  end

  save_budget_data_to_yaml(budget)

  redirect "/"
end

post "/budget/:category_name/delete" do
  # Force user to have at least one active category
  #unless more_than_one_category_exists?
  #  session[:message] = "Can't delete category - you must have at least one category."
  #  redirect "/"
  #end

  budget = load_yaml_file("budget.yaml")
  category_name = params[:category_name]

  # Prevent user-generated URLs to delete files
  unless budget[:categories].include?(category_name)
    session[:message] = "Can't delete - that category doesn't exist!"
    redirect "/"
  end

  budget[:categories].delete(category_name)
  save_budget_data_to_yaml(budget)

  session[:message] = "#{category_name} successfully deleted. NOTE: Update your spending data categories accordingly!"
  redirect "/"
end

get "/budget/purchases/:purchase_id/edit" do
  purchases = load_yaml_file("spending.yaml")
  purchase_index = params[:purchase_id].to_i
  @purchase = purchases[purchase_index]
  @budget = load_yaml_file("budget.yaml")
  erb :edit_purchase
end

post "/budget/purchases/:purchase_id/update" do
  purchase_index = params[:purchase_id].to_i

  if invalid_number?(params[:amount])
    session[:message] = "Invalid number!"
    status 422
    redirect "/budget/purchases/#{purchase_index}/edit"
  end

  date = return_formatted_date(params[:date])

  purchase = { category: params[:category],
               date:     date,
               amount:   format_money(params[:amount])
              }



  update_purchase(purchase, purchase_index)
  session[:message] = "Purchase successfully updated."
  redirect "/"
end

post "/budget/purchases/:purchase_id/delete" do
  purchase_index = params[:purchase_id].to_i

  delete_purchase(purchase_index)
  session[:message] = "Purchase successfully deleted."
  redirect "/"
end
