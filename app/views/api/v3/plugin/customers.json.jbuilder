json.array!(@companies) do |company|
  users = company.users.where(:roles_mask.lte => 4).where(:plugin_token.ne => nil).all
  campaigns = Campaign.active.where(company_id: company.id, :_type.nin => ["RemovedLeadsCampaign", "InboundCampaign"]).order_by(:updated_at => 'desc').only(:_id, :name, :user_id, :updated_at, :created_at).all.to_a || []
  if (users.any?)
    json.extract! company, :id, :name
    json.users do |json|
      json.array!(users) do |user|
        json.extract! user, :id, :email, :full_name, :plugin_token unless user.blank?
      end
    end
    json.campaigns do |json|
      json.array!(campaigns) do |campaign|
        json.extract! campaign, :_id, :name, :user_id, :updated_at, :created_at
      end
    end
  end
end
