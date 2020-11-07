class ForeignProspectMapping
  include Mongoid::Document
  include Mongoid::Timestamps
  # these fields are implied
  # field :lead_id, type: BSON::ObjectId
  # field :prospected_by_company_id, type: BSON::ObjectId #current_user.company_id
  field :last_synced_at, type: DateTime
  field :foreign_id, type: String
  field :foreign_owner_id, type: String # this could be difficult to keep in sync
  field :foreign_source_name, type: String, default: "salesforce"

  embedded_in :prospect, inverse_of: :foreign_prospect_mappings
end
