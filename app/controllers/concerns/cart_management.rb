module CartManagement
  extend ActiveSupport::Concern

  private

  def set_cart
    # TODO: Replace with actual user authentication
    user_id = params[:user_id] || "1"
    user = User.find_or_create_by(id: user_id) do |u|
      u.email = "user#{user_id}@example.com"
      u.name = "User #{user_id}"
    end
    @cart = user.cart || user.create_cart
  end
end
