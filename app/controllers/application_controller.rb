class ApplicationController < ActionController::API
  # def authenticate_user!
  #  byebug
  #  super
  # end

  before_action :skip_trackable

  def skip_trackable
    request.env['devise.skip_trackable'] = true
  end
end
