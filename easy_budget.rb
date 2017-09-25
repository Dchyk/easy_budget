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
  purchases << purchase

  File.open(get_yaml_path("spending.yaml"), "w") do |file|
      file.write(purchases.to_yaml)
    end
end

def save_budget(budget)
  budget_file = load_yaml_file("budget.yaml")
  budget_file << budget

  File.open(get_yaml_path("budget.yaml"), "w") do |file|
      file.write(purchases.to_yaml)
    end
end

def test_yaml_spending
  spending = []


  spending << {category: "gas", date: "9/20/17", amount: 50}
  spending << {category: "grocery", date: "9/21/17", amount: 100}


  save_purchase(spending)
end

helpers do 
  # Define view helper to add up total monthly income
  # etc.?
end

get "/" do
  require_signin

  #test_yaml_spending

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
  # Require a budget to exist
  require_signed_in_user

  erb :add_spending
end

post "/save_purchase" do
  purchase = { category: params[:category],
               date:     params[:date],
               amount:   params[:amount]
             }

  save_purchase(purchase)
  session[:message] = "Purchase successfully recorded."
  redirect "/"
end

get "/budget/create_budget" do

  erb :create_budget

end

post "/budget/add_income" do 
  monthly_income = { income: params[:income] }

  budget_file = load_yaml_file("budget.yaml")
  budget_file[:monthly_income] = monthly_income



  session[:message] = "Income successfully recorded."
  redirect "/budget/add_categories"
end

get "/budget/edit_income" do

  @budget = load_yaml_file("budget.yaml")
  erb :edit_income

end

post "/budget/update_income" do


end