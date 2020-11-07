namespace :fetchables do
  desc "Reindex Fetchables"
  task reindex: :environment do
    Plugin::Fetchable.reindex
  end

  desc "report on the total number of fetchables with a 404 status"
  task count_404s: :environment do
    fetchables = Plugin::Fetchable.where(response_status: "404")
    STDERR.puts "total 404 fetchables: #{fetchables.count}"
  end

  desc "reset fetchables with user given by EMAIL"
  task reset_by_email: :environment do
    unless ENV['EMAIL']
      raise "missing EMAIL environment variable"
    end

    user = User.find_by(email: ENV['EMAIL'])

    fetchables = Plugin::Fetchable
                 .where(user_id: user.id, response_status: "404")
                 .limit(ENV['LIMIT'] || 150)
                 .order(created_at: "ASC")

    log_message = "updating #{fetchables.to_a.count} fetchables for #{user.email}, eg: #{fetchables.first.inspect}"
    STDERR.puts log_message

    raise_unless_confirmed

    fetchables.each do |f|
      f.update_attributes(response_status: nil)
    end

    EventLog.info log_message, event: :reset_by_email, user: user
  end

  desc "reset fetchables with campaign given by CAMPAIGN_ID"
  task reset_by_campaign: :environment do
    unless ENV['CAMPAIGN_ID']
      raise "missing CAMPAIGN_ID environment variable"
    end

    campaign = Campaign.find(ENV['CAMPAIGN_ID'])

    fetchables = Plugin::Fetchable
                 .where(campaign_id: campaign.id, response_status: "404")
                 .limit(ENV['LIMIT'] || 150)
                 .order(created_at: "ASC")

    log_message = "updating #{fetchables.to_a.count} fetchables for '#{campaign.name}', eg: #{fetchables.first.inspect}"
    STDERR.puts log_message

    raise_unless_confirmed

    fetchables.each do |f|
      f.update_attributes(response_status: nil)
    end

    EventLog.info log_message, event: :reset_by_campaign, campaign: campaign
  end
end

def raise_unless_confirmed
  unless ENV['CONFIRM'] == '1'
    raise "missing CONFIRM=1"
  end
end
