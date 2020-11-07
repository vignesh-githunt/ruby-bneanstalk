class Api::V3::PluginController < ApplicationController
  before_action :authenticate_user!

  def fetchables_pop
    service = FetchableService.new

    fetchables_count = service.queue_size(current_user._id)
    next_to_fetch = service.queue_pop(current_user._id)

    delay = rand(5000...10000)
    render json: { minables: [next_to_fetch], delay: delay, pending_count: fetchables_count }
  end

  def campaigns_status
    # #campaigns = Campaign.where(company_id:current_user.company_id).all
    my_campaigns = Campaign.active.where(company_id: current_user.company_id, user_id: current_user._id, :_type.nin => ["RemovedLeadsCampaign", "InboundCampaign"]).order_by(:updated_at => 'desc').only(:_id, :name, :user_id, :updated_at, :created_at).all.to_a || []
    # #my_campaigns = []
    team_campaigns = []
    team_campaigns = Campaign.active.where(company_id: current_user.company_id, :user_id.ne => current_user._id, :_type.nin => ["RemovedLeadsCampaign", "InboundCampaign"]).order_by(:updated_at => 'desc').only(:_id, :name, :user_id, :updated_at, :created_at).all.to_a || []

    campaign_ids = my_campaigns.map &:_id
    #
    # #company_campaigns = current_user.company.campaigns.where(user_id:)
    fetchables_size = 0
    # has_fetchables = Plugin::Fetchable.where(user_id:current_user._id,response_status:nil).any?
    # current_campaign_id = get_current_campaign_id(campaign_ids,current_user._id)
    current_campaign_id = current_user.current_campaign_id
    if (current_campaign_id.blank?)
      current_campaign_id = my_campaigns.first._id.to_s if my_campaigns.any?
    end
    if (current_campaign_id.blank?)
      current_campaign_id = team_campaigns.first._id.to_s if team_campaigns.any?
    end
    #
    # campaign.as_json is causing a lot of extra mongo queries...
    @my_campaigns = my_campaigns || []
    @team_campaigns = team_campaigns || []
    @current_campaign_id = current_campaign_id || nil
    @credits_remaining = current_user.company.credits_remaining
    @fetchables_size = fetchables_size
    @users = {}
    @users[current_user._id.to_s] = current_user.full_name
    team_user_ids = @team_campaigns.map &:user_id
    team_user_ids = team_user_ids.uniq
    company_users = Rails.cache.fetch("company_users_#{current_user.company_id.to_s}", :expires_in => 1.hours) do
      current_user.company.users.where(:_id.in => team_user_ids).only(:_id, :first_name, :last_name).to_a
    end
    company_users.each do |user|
      @users[user._id.to_s] = "#{user.first_name} #{user.last_name}"
    end
    # result = {
    # campaigns:my_campaigns || [],
    # current_campaign_id: current_campaign_id || nil,
    # company_campaigns:team_campaigns || [],
    # creditsRemaining:current_user.company.credits_remaining,
    # minablesPending:fetchables_size,
    # features:{
    #   company_search:false,
    #   basic_salesforce:false,
    #   premium_salesforce:false,
    #   kickoff_call:false,
    #   list_sync:false,
    #   extension_sfdc_search:false,
    #   sfdc_mapping:false,
    #   always_be_scraping:false
    # },
    # pluginToken:"#{current_user.plugin_token}"
    # }
    # render json: result
    # render json: {}
  end

  def customers
    # manual authorization because CanCan is not currently setup to work here
    if (current_user.roles_mask == 1)
      @companies = Company.where(isCustomer: true).order_by(:name => 'asc').all
    else
      @companies = []
    end
  end

  # this should return the same as campaign status but for a specific accountId/customerId
  def customer_campaigns
    # manual authorization because CanCan is not currently setup to work here
    if (current_user.roles_mask == 1)
      customer_id = params[:id]
      my_campaigns = [] # Campaign.active.where(company_id:current_user.company_id,user_id:current_user._id,:_type.nin => ["RemovedLeadsCampaign","InboundCampaign"]).order_by(:updated_at => 'desc').only(:_id,:name,:user_id,:updated_at,:created_at).all.to_a || []
      # #my_campaigns = []
      team_campaigns = []
      team_campaigns = Campaign.active.where(company_id: customer_id, :_type.nin => ["RemovedLeadsCampaign", "InboundCampaign"]).order_by(:updated_at => 'desc').only(:_id, :name, :user_id, :updated_at, :created_at).all.to_a || []

      # campaign_ids = my_campaigns.map &:_id

      fetchables_size = 0
      current_campaign_id = nil

      if (current_campaign_id.blank?)
        current_campaign_id = my_campaigns.first._id.to_s if my_campaigns.any?
      end
      if (current_campaign_id.blank?)
        current_campaign_id = team_campaigns.first._id.to_s if team_campaigns.any?
      end
      #
      # campaign.as_json is causing a lot of extra mongo queries...
      @my_campaigns = my_campaigns || []
      @team_campaigns = team_campaigns || []
      @current_campaign_id = current_campaign_id || nil
      @credits_remaining = current_user.company.credits_remaining
      @fetchables_size = fetchables_size
      @users = {}
      @users[current_user._id.to_s] = current_user.full_name
      team_user_ids = @team_campaigns.map &:user_id
      team_user_ids = team_user_ids.uniq
      company_users = Rails.cache.fetch("company_users_#{current_user.company_id.to_s}", :expires_in => 1.hours) do
        current_user.company.users.where(:_id.in => team_user_ids).only(:_id, :first_name, :last_name).to_a
      end
      company_users.each do |user|
        @users[user._id.to_s] = "#{user.first_name} #{user.last_name}"
      end
    else

    end

    render :campaigns_status
  end

  def get_current_campaign_id(campaign_ids, current_user_id)
    # Rails.cache.fetch("current_campaign_id_#{current_user._id.to_s}", :expires_in => 10.minutes) do
    current_campaign_id = Plugin::Fetchable.where(:campaign_id.in => campaign_ids, user_id: current_user_id).order_by(updated_at: -1).only(:campaign_id).first
    current_campaign_id = current_campaign_id.campaign_id unless current_campaign_id.blank?
    # end
  end

  def whoami
    # if(params[:v] != "0.1.55")
    # current_user.send_message_to_plugin("server-notification","You need to reload the plugin.")
    # end
    EventLog.success "SDR extension initialising", event: :extension_initialising, user: current_user, params: params
    render json: { user_id: "#{current_user._id.to_s}", user_info: { name: "#{current_user.full_name}", email: "#{current_user.email}" } }
  end

  def pusher_auth
    channel = params[:channel_name]
    current_user.update_attribute(:pusher_channel, channel)

    auth = Pusher[channel].authenticate(params[:socket_id], { user_id: current_user._id.to_s, user_info: { name: "#{current_user.full_name}", email: "#{current_user.email}" } })
    EventLog.success "pusher authenticated (v3)", event: :pusher_auth, user: current_user, params: params, auth: auth

    render json: auth
  end

  # check_prospected_by_ids
  def import_histories
    ids = params[:ids]
    account_id = params[:accountId] || current_user.company_id
    unless ids.blank?
      # result = Plugin::Fetchable.in(profile_uid: ids).where(user_company_id:current_user.company_id).and(:response_status.in =>[nil,"200","404"]).only(:_id,:profile_uid,:updated_at,:created_at,:campaign_id,:user_id,:user_company_id).all || []
      # if result.blank?
      # result = Plugin::Fetchable.in(profile_uid: ids).where(user_id:current_user._id).only(:_id,:profile_uid,:updated_at,:created_at,:campaign_id,:user_id).all || []
      # end
      service = FetchableService.new
      result = service.check_prospected_by_ids(account_id, current_user._id, ids)
      fetchables = []
      result.each do |f|
        unless f.profile_uid.blank?
          unless fetchables.any? { |x| x[:source_uid] == f.profile_uid }
            fetchables << {
              source_uid: f.profile_uid,
              owned_by_me: f.user_id == current_user._id.to_s,
              created_at: f.updated_at || f.created_at,
              updated_at: f.updated_at || f.created_at,
              added_to_campaign: !f.campaign_id.blank?,
              campaign_id: f.campaign_id
            }
          else
            if fetchables.any? { |x| x[:source_uid] == f.profile_uid && x[:added_to_campaign] == false } && !f.campaign_id.blank?
              fetchables.select { |x| x[:source_uid] == f.profile_uid }.first[:added_to_campaign] = true
            end
          end
        end
      end
      render json: fetchables
    else
      render json: []
    end
  end
  alias_method :check_prospected_by_ids, :import_histories

  def check_prospected_by_urls
    urls = params[:urls]
    account_id = params[:accountId] || current_user.company_id
    unless urls.blank?
      result = Plugin::Fetchable.in(url: urls).where(user_company_id: account_id).and(:response_status.in => [nil, "200", "404"]).only(:_id, :profile_uid, :updated_at, :created_at, :campaign_id, :user_id, :user_company_id, :url).all || []
      if result.blank?
        result = Plugin::Fetchable.in(url: urls).where(user_id: current_user._id).only(:_id, :profile_uid, :updated_at, :created_at, :campaign_id, :user_id, :url).all || []
      end
      fetchables = []
      result.each do |f|
        unless f.profile_uid.blank?
          unless fetchables.any? { |x| x[:source_uid] == f.profile_uid }
            fetchables << {
              url: f.url,
              source_uid: f.profile_uid,
              owned_by_me: f.user_id == current_user._id,
              created_at: f.updated_at || f.created_at,
              updated_at: f.updated_at || f.created_at,
              added_to_campaign: !f.campaign_id.blank?
            }
          else
            if fetchables.any? { |x| x[:source_uid] == f.profile_uid && x[:added_to_campaign] == false } && !f.campaign_id.blank?
              fetchables.select { |x| x[:source_uid] == f.profile_uid }.first[:added_to_campaign] = true
            end
          end
        end
      end
      render json: fetchables
    else
      render json: []
    end
  end

  def fetchables_incr
    render json: { count: 1 }
  end

  def is_prospected
    url = params[:url]
    re = ::Regexp.new("[^srch]id=([0-9]+)")
    fetchable = nil
    id = re.match(url)[1] unless re.match(url).nil?
    if id.blank?
      re = ::Regexp.new("sales/profile/([0-9]+)")
      id = re.match(url)[1] unless re.match(url).nil?
    end
    unless id.blank?
      fetchable = Plugin::Fetchable.where(profile_uid: "linkedin_profile-#{id}", user_company_id: current_user.company_id, response_status: "200").only(:_id, :profile_uid, :user_id, :updated_at, :campaign_id).first
    else
      fetchable = Plugin::Fetchable.where(url: /#{url}/, user_company_id: current_user.company_id, type: "linkedin_user_profile", response_status: "200").only(:_id, :profile_uid, :user_id, :updated_at, :campaign_id).first
    end

    unless fetchable.blank?
      f = {
        source_uid: fetchable.profile_uid,
        owned_by_me: fetchable.user_id == current_user._id,
        updated_at: fetchable.updated_at,
        added_to_campaign: !fetchable.campaign_id.blank?
      }
      render json: { success: true, minable: f }
    else
      render json: { success: false, minable: nil }
    end
  end

  def status
    status = current_user.record_extension_status(status_params)
    render json: { success: true, status: status }
  end

  def status_params
    params.require(:plugin).permit(:linkedin, :platform, :websocket, :sales_navigator, :version)
  end
end
