json.campaigns do |json|
  json.array! @my_campaigns do |campaign|
    json.extract! campaign, :_id, :name, :updated_at, :created_at, :user_id
    json.teammate @users[campaign.user_id.to_s] if @users.has_key? campaign.user_id.to_s
  end
end
json.current_campaign_id @current_campaign_id
json.company_campaigns do |json|
  json.array! @team_campaigns do |campaign|
    json.extract! campaign, :_id, :name, :updated_at, :created_at, :user_id
    json.teammate @users[campaign.user_id.to_s] if @users.has_key? campaign.user_id.to_s
  end
end
json.creditsRemaining @credits_remaining
json.minablesPending @fetchables_size
json.features do |json|
end
json.pluginToken "#{current_user.plugin_token}"
