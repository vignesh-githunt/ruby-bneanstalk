class Api::V3::StatsController < ApplicationController
  before_action :authenticate_user!

  def pending_requests
    service = FetchableService.new

    queue_size = service.queue_size(current_user._id)

    render json: { pending_requests: queue_size }
  end

  def all_pending_requests
    service = FetchableService.new

    user_queues = []

    current_user.company.users.where(:roles_mask.lte => 4).each do |employee|
      q = service.queue_size(employee._id)
      user_queues << { _id: employee._id, queue_size: q, name: employee.full_name }
    end

    render json: { user_queues: user_queues }
  end

  def campaign_progress
    service = FetchableService.new
    campaign_id = params[:campaign_id]

    progress = service.get_campaign_progress(campaign_id)

    render json: { progress: progress }
  end
end
