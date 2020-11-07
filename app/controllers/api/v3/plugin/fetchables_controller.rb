class Api::V3::Plugin::FetchablesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_plugin_fetchable, only: [:show, :update, :destroy]

  # GET /api/v3/plugin/fetchables
  # GET /api/v3/plugin/fetchables.json
  def index
    @plugin_fetchables = ::Plugin::Fetchable.all
  end

  # GET /api/v3/plugin/fetchables/1
  # GET /api/v3/plugin/fetchables/1.json
  def show
  end

  # POST /api/v3/plugin/fetchables
  # POST /api/v3/plugin/fetchables.json
  def create
    EventLog.info "create", params: params
    fetchables = plugin_fetchables_params
    plugin_fetchables = []
    fetchables.each do |f|
      if (f["url"].include?("linkedin.com"))
        handle_linkedin(f, plugin_fetchables)
      elsif (f["url"].include?("zoominfo.com"))
        handle_zoominfo(f, plugin_fetchables)
      elsif (f["url"].include?("discoverydb.com"))
        handle_discoverorg(f, plugin_fetchables)
      else
        f.log "url does not match any known type", :error
      end
    end
    unless plugin_fetchables.blank?
      # Plugin::Fetchable.collection.insert_many(plugin_fetchables.map(&:as_document))
      plugin_fetchables.each do |f|
        f.save
        f.log "saved new fetchable", :success
      end
    end
    current_user.send_message_to_plugin("minables-updated")

    render json: { success: true }, status: :created
  end

  # PATCH/PUT /api/v3/plugin/fetchables/1
  # PATCH/PUT /api/v3/plugin/fetchables/1.json
  def update
    @plugin_fetchable.log "update #{@plugin_fetchable.response_status}"
    if @plugin_fetchable.update(plugin_fetchable_params)
      @plugin_fetchable.update_attribute(:fetched_at, DateTime.now)

      if @plugin_fetchable.response_status == "200"
        # Everything looks good from the client, dispatch this for processing.
        @plugin_fetchable.dispatch
      else
        # We got a 4xx or 5xx in the response_body. Do not process it.
        # Mark it with a worker_status error for further investigation.
        @plugin_fetchable.set_worker_status(Plugin::Fetchable::Status::CLIENT_RESPONSE_STATUS_ERROR)
      end

      service = FetchableService.new
      fetchables_count = service.queue_size(current_user._id)
      render json: { pending_count: fetchables_count }
    else
      # In this case, the params are bad, and we could not update the
      # fetchable with them.  We don't know the status of the
      # fetchable itself, but we will add an error to it so we can
      # investigate it and attach validation error details to a log
      # message associated with this fetchable
      @plugin_fetchable.log "unprocessable request", :error, errors: @plugin_fetchable.errors
      @plugin_fetchable.set_worker_status(Plugin::Fetchable::Status::UPDATE_VALIDATION_FAILED)
      render json: @plugin_fetchable.errors, status: :unprocessable_entity
    end
  end

  # DELETE /api/v3/plugin/fetchables/1
  # DELETE /api/v3/plugin/fetchables/1.json
  def destroy
    @plugin_fetchable.log "destroy", :info
    @plugin_fetchable.destroy
  end

  private

  def handle_zoominfo(f, plugin_fetchables)
    profile_uid = "zoominfo_profile-"
    re = ::Regexp.new("personId=([\-0-9]+)")
    id = f["url"].match(re)[1] if f["url"].match(re)
    profile_uid += id unless id.nil?

    unless ::Plugin::Fetchable.where(user_company_id: current_user.company_id.to_s, profile_uid: profile_uid).exists? || ::Plugin::Fetchable.where(user_company_id: current_user.company_id.to_s, url: f["url"]).exists?
      plugin_fetchables << ::Plugin::Fetchable.new(type: f["type"],
                                                   url: f["url"],
                                                   description: f["description"],
                                                   source: params[:source],
                                                   campaign_id: params[:campaign_id],
                                                   user_id: current_user._id.to_s,
                                                   profile_uid: profile_uid,
                                                   user_company_id: current_user.company_id,
                                                   priority: 10)
    else

    end
  end

  def handle_linkedin(f, plugin_fetchables)
    logopts = { event: :handle_linkedin, f: f }
    EventLog.info "handling linkedin", logopts
    profile_uid = "linkedin_profile-"
    re = ::Regexp.new("[^srch]id=([0-9]+)")
    id = f["url"].match(re)[1] if f["url"].match(re)
    if id.nil?
      re = Regexp.new("id=([^&]+)")
      id = f["url"].match(re)[1] if f["url"].match(re)
    end
    if id.blank? && (f["url"].include?("sales/profile/") || f["url"].include?("sales/people/"))
      # sales navigator search or profile url
      re = ::Regexp.new("sales\/(profile|people)\/([\\w|_|-]+)\,")
      id = f["url"].match(re)[2] if f["url"].match(re)
    end
    profile_uid += id unless id.nil?
    if f["description"].include?("| LinkedIn")
      f["description"] = f["description"].split("|").first.strip
    end
    # if id is blank we have a public profile.
    if id.blank?
      if f["url"].include?("/in/")
        name = f["url"].split("/").last
      elsif f["url"].include?("/pub/")
        name = f["url"].split("/pub/").last.gsub("/", "-")
      else
        name = f["description"].gsub(" ", "-")
      end
      profile_uid = "linkedin_public_profile-#{name}"
    end
    unless ::Plugin::Fetchable.where(user_company_id: current_user.company_id.to_s, profile_uid: profile_uid).exists? || ::Plugin::Fetchable.where(user_company_id: current_user.company_id.to_s, url: f["url"]).exists?
      plugin_fetchables << ::Plugin::Fetchable.new(type: f["type"],
                                                   url: f["url"],
                                                   description: f["description"],
                                                   source: params[:source],
                                                   campaign_id: params[:campaign_id],
                                                   user_id: current_user._id.to_s,
                                                   profile_uid: profile_uid,
                                                   user_company_id: current_user.company_id,
                                                   priority: 10)
    else
      unless id.blank? # this will never happen
        EventLog.error "this will never happen MeTWDCAAsJoTHbAGZ", logopts
        unless params[:campaign_id].blank?
          ::Plugin::Fetchable.where(user_company_id: current_user.company_id.to_s, profile_uid: profile_uid).update(campaign_id: params[:campaign_id])
          lead = User.where(linkedin_id: id).first
          campaign = Campaign.find(params[:campaign_id])
          campaign.add_lead(lead) unless lead.blank?
        end
      else
        # we will hit here for leads that are dupes
        EventLog.warn "dupe lead: #{f['url']}", logopts
      end
    end
  end

  def handle_discoverorg(f, plugin_fetchables)
    profile_uid = "discoverorg_profile-"
    re = ::Regexp.new(/\/persons\/([0-9]+)/)
    id = f["url"].match(re)[1] if f["url"].match(re)
    profile_uid += id unless id.nil?
    # we have a lot more data here that we could use to store information about the lead being added at this point.
    url = "https://go.discoverydb.com/eui/api/rest/persons/#{id}" unless id.nil?
    unless ::Plugin::Fetchable.where(user_company_id: current_user.company_id.to_s, profile_uid: profile_uid).exists? || ::Plugin::Fetchable.where(user_company_id: current_user.company_id.to_s, url: f["url"]).exists?
      plugin_fetchables << ::Plugin::Fetchable.new(type: f["type"],
                                                   url: url || f["url"],
                                                   description: f["description"],
                                                   source: params[:source],
                                                   campaign_id: params[:campaign_id],
                                                   user_id: current_user._id.to_s,
                                                   profile_uid: profile_uid,
                                                   user_company_id: current_user.company_id,
                                                   priority: 10)
    else

    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_plugin_fetchable
    @plugin_fetchable = ::Plugin::Fetchable.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def plugin_fetchable_params
    params.require(:plugin_minable).permit(:url, :description, :type, :source, :response_body, :response_status, :response_url, :response_redirected, :response_content_type, :user_id, :campaign_id, :company_id, :company_linkedin_id, :profile_uid, :lead_id)
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def plugin_fetchables_params
    defaults = { "type" => "linkedin_user_profile" } # temporary fix - v6.0.0.4 of extension doesn't set this
    fetchables = params.fetch(:minables, [])
    fetchables.map do |f|
      defaults.merge(f.permit!)
    end
  end
end
