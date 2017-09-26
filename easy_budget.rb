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

def save_income(income)
  budget_file = load_yaml_file("budget.yaml")
  budget_file[:monthly_income] = income

  File.open(get_yaml_path("budget.yaml"), "w") do |file|
      file.write(budget_file.to_yaml)
    end
end

def add_expense_category(category_name, amount)
  budget_file = load_yaml_file("budget.yaml")

  if budget_file[:categories].nil?
    budget_file[:categories] = { category_name => amount }
  else
    budget_file[:categories][category_name] = amount
  end

  File.open(get_yaml_path("budget.yaml"), "w") do |file|
      file.write(budget_file.to_yaml)
    end  
end

def invalid_number?(input)
  no_value?(input) || input.match(/\D/)
end

def invalid_name?(input)
  no_value?(input) == 0 || input.match(/\W/)
end

def no_value?(input)
  input.size == 0
end

def validate_purchase
  # needed
end

helpers do
  def total_spending_in_one_category(category)
    spending = load_yaml_file("spending.yaml")
    category_spending = spending.select { |purchase| purchase[:category] == category }
    total = category_spending.map { |selected_purchase| selected_purchase[:amount].to_i }.inject(&:+)
    total || 0
  end

  def total_money_budgeted
    budget = load_yaml_file("budget.yaml")

    budget[:categories].map { |_, amount| amount.to_i }.inject(&:+)
  end

  def money_available_to_budget
    budget_file = load_yaml_file("budget.yaml")
    budget_file[:monthly_income].to_i - total_money_budgeted
  end

  def todays_date
    date = Time.now
    "#{date.month}/#{date.day}/#{date.year}"
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

get "/add_spending" do
  require_signed_in_user

  @budget = load_yaml_file("budget.yaml") 

  erb :add_spending
end

post "/save_purchase" do
  #validate_purchase

  purchase = { category: params[:category],
               date:     params[:date],
               amount:   params[:amount]
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
    add_expense_category(category_name, amount)
    session[:message] = "#{category_name} category added to monthly expenses."
    redirect "/"
  end
end