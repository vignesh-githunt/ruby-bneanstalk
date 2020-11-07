class Prospect
  include Mongoid::Document
  include Mongoid::Timestamps
  # lead details
  field :lead_id, type: BSON::ObjectId
  field :full_name, type: String # lead full name
  field :image_url, type: String
  field :title, type: String

  # account details
  field :account_id, type: BSON::ObjectId
  field :account_name, type: String # easily accessible
  field :account_website_url, type: String # easily accessible

  # campaign details
  field :campaign_id, type: BSON::ObjectId
  field :campaign_name, type: String

  # processing details
  # field :last_added, type: Date #have this here to be able to track the diff between adding and processing
  field :last_processed, type: Date
  field :processed_count, type: Integer
  field :prospected_by_company_id, type: BSON::ObjectId # current_user.company_id
  field :last_prospected_by_user_id, type: BSON::ObjectId # current_user._id
  field :last_prospected_by_user_full_name, type: String
  field :prospected_by_user_ids, type: Array # list of all users that have prospected this user
  field :prospect_urls, type: Array # list of all urls that this user was prospected on

  embeds_many :foreign_prospect_mappings

  index({ prospected_by_company_id: 1, lead_id: 1 }, { unique: true })

  # elasticsearch
  # document_type "prospect"

  def as_indexed_json(options = {})
    as_json(except: [:id, :_id])
  end

  def self.from_user(current_user, lead)
    # make idempotent

    # find the tracking data object
    tracking = UserDataTracking.where(lead_id: lead._id, current_company_id: current_user.company_id).last
    tracking_count = UserDataTracking.where(lead_id: lead._id, current_company_id: current_user.company_id).count()
    if tracking
      prospected_by_user = User.find(tracking.current_user_id)
      campaign = Campaign.find(tracking.campaign_id)
      # find the related fetchables
      fetchables = Plugin::Fetchable.where({ :_id.in => tracking.fetchable_ids }).only(:url, :campaign_id, :updated_at, :user_id).all
      prospected_by_user_ids_array = [prospected_by_user._id]
      prospect_urls = fetchables.map &:url || []
      if (tracking_count > 1)
        # trackings = UserDataTracking.where(lead_id:lead._id,current_company_id:current_user.company_id).all
        # trackings.each do |t|
        #  prospect_urls
        # end

      end

      prospect = nil
      unless self.where(lead_id: lead._id, prospected_by_company_id: current_user.company_id).any?
        prospect = self.create(lead_id: lead._id,
                               full_name: lead.full_name,
                               image_url: lead.image_url,
                               title: lead.title,
                               account_id: lead.company_id,
                               account_name: lead.company.name,
                               account_website_url: lead.company.website_url,
                               campaign_id: tracking.campaign_id,
                               campaign_name: campaign.name,
                               last_processed: tracking.updated_at,
                               processed_count: tracking_count,
                               prospected_by_company_id: tracking.current_company_id,
                               last_prospected_by_user_id: prospected_by_user._id,
                               last_prospected_by_user_full_name: prospected_by_user.full_name,
                               prospected_by_user_ids: prospected_by_user_ids_array,
                               prospect_urls: prospect_urls)
      else
        # implement update of the prospect here
        prospect = self.where(lead_id: lead._id, prospected_by_company_id: current_user.company_id).first
        prospect.update_attributes(full_name: lead.full_name,
                                   image_url: lead.image_url,
                                   title: lead.title,
                                   account_id: lead.company_id,
                                   account_name: lead.company.name,
                                   account_website_url: lead.company.website_url,
                                   campaign_id: tracking.campaign_id,
                                   campaign_name: campaign.name,
                                   last_processed: tracking.updated_at,
                                   processed_count: tracking_count,
                                   prospected_by_company_id: tracking.current_company_id,
                                   last_prospected_by_user_id: prospected_by_user._id,
                                   last_prospected_by_user_full_name: prospected_by_user.full_name,
                                   prospected_by_user_ids: prospected_by_user_ids_array,
                                   prospect_urls: prospect_urls)
      end

      mappings = []
      ForeignUserMapping.where(lead_id: lead._id, company_id: current_user.company_id).to_a.each do |mapping|
        owner_id = nil
        if mapping.foreign_source_name == "salesforce_contact"
          # fetch the owner_id
          # owner_id = nil
        end
        unless prospect.foreign_prospect_mappings.where(foreign_source_name: mapping.foreign_source_name).any?
          prospect.foreign_prospect_mappings.create(foreign_id: mapping.foreign_id,
                                                    foreign_owner_id: owner_id,
                                                    foreign_source_name: mapping.foreign_source_name)
        else
          # update the mapping
          updated_mapping = prospect.foreign_prospect_mappings.where(foreign_source_name: mapping.foreign_source_name).first
          updated_mapping.update_attributes(foreign_id: mapping.foreign_id,
                                            foreign_owner_id: owner_id,
                                            foreign_source_name: mapping.foreign_source_name)
        end
      end
      prospect
    else
      # do something here for leads without tracking objects
    end
  end
end
