ENV["RACK_ENV"] = "test"

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative '../easy_budget.rb'

class EasyBudgetTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin"} }
  end

  def test_index_signed_in
    get "/", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "** Easy Budget **"
    # load a testing version of spending items
    # load a testing version of budget items
  end

  def test_index_not_signed_in
    get "/"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "Sign In"
    assert_includes last_response.body, "username and password:"
  end

  def test_user_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome, admin!", session[:message]
    assert_equal "admin", session[:username]
  end

  def test_user_signin_invalid_credentials
    post "/users/signin", username: "test", password: "test"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Invalid credentials."
    assert_nil session[:username] 
  end

  def test_user_signout
    post "/users/signout", {}, admin_session

    get last_response["Location"]

    assert_equal "You've been signed out.", session[:message]
  end

  def test_add_spending_not_signed_in
    skip
    get "/add_spending", username: nil

    get last_response["Location"]

    assert_includes last_response.body, "Username"
  end

  def test_save_purchase
    post "/save_purchase", category: "Restaurants", date: "9/21/17", amount: "59.68"

    assert_equal "Purchase successfully recorded.", session[:message]

    # How to test that the purchase is showing up correctly?

    # get "/"
    #
    # assert_includes last_response.body, "$59.68 in the Restaurants category on 9/21/17"
  end

  def test_add_category
    get "/budget/add_category", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Add a Category of Monthly Expenses:"

    post "/budget/add_category", category_name: "Test", amount: 130
    assert_equal "Test category added to monthly expenses.", session[:message]

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Test: $"
    assert_includes last_response.body, %q(<strong>130.00</strong>)
  end

  def test_add_invalid_category
    get "/budget/add_category", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Add a Category of Monthly Expenses:"

    post "/budget/add_category", category_name: "Parts & Labor", amount: 100
    assert_includes last_response.body, "Invalid category name - only numbers and letters allowed!"
  end

  def test_add_duplicate_category
    post "/budget/add_category", { category_name: "Test", amount: 100 }, admin_session
    assert_includes last_response.body, "Category name already exists - please choose a unique name!"
  end

  def test_edit_income
    get "/budget/edit_income", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Update your monthly income"
    assert_includes last_response.body, %q(<button class="edit")
    assert_includes last_response.body, %q(<button class="delete")
  end

  def test_edit_income_invalid_input
    post "/budget/edit_income", { income: " "}, admin_session
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Invalid number!"
  end

  def test_edit_category
    skip
  end

  def test_edit_category_invalid_input
    skip
  end

  def test_delete_category
    skip
  end

  def test_view_all_spending
    skip
  end

  def test_edit_and_save_purchase
    skip
  end

  def test_edit_purchase_invalid_input
    skip
  end

  def test_delete_purchase
    skip
  end

  def test_spending_exceeds_income_warning
    skip
  end


end