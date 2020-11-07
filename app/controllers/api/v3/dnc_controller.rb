class Api::V3::DncController < ApplicationController
  before_action :authenticate_user!

  def check
    service = DoNotContactCheckService.new(params[:customer_id])
    result = service.check(params[:email])
    render json: result
  end
end
