require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "create with valid params signs the user in" do
    assert_difference "User.count", 1 do
      post registration_path, params: { user: { email_address: "new@example.com", password: "secret123", password_confirmation: "secret123" } }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with mismatched passwords re-renders the form" do
    assert_no_difference "User.count" do
      post registration_path, params: { user: { email_address: "new@example.com", password: "secret123", password_confirmation: "different" } }
    end

    assert_response :unprocessable_content
  end

  test "create with a taken email re-renders the form" do
    assert_no_difference "User.count" do
      post registration_path, params: { user: { email_address: users(:one).email_address.upcase, password: "secret123", password_confirmation: "secret123" } }
    end

    assert_response :unprocessable_content
  end

  test "create ignores params that are not permitted" do
    post registration_path, params: { user: { email_address: "new@example.com", password: "secret123", password_confirmation: "secret123", id: 999 } }

    assert_not_equal 999, User.find_by(email_address: "new@example.com")&.id
  end
end
