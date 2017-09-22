require 'yaml'
require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'

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
  YAML.load('./users.yaml')
end

get "/" do
  require_signin

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