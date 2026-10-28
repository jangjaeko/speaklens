require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "redirects to sign in when signed out" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "shows the signed-in user" do
    sign_in_as users(:one)
    get root_path
    assert_response :success
    assert_match users(:one).email_address, response.body
  end
end
