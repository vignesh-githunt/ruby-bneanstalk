# require 'csv'

namespace :prospecting do
  desc "query prospecting information"
  # arguments: model_name field_name
  # usage: bundle exec rake fix:booleans ProductWizard active
  task report: :environment do
    companies = Company.find([
                               "5548bab531313900030f0000", # Collective[i]
                               "557a95093631370003f40a00", # Tripactions
                               "5b05d6dccd3a6e039d923316", # ActOn
                               "5609e2f0326335000a0e0000", # Aircall
                               "54de87473833640003000000", # Memsql
                               "54d939213430330003010100", # Wiser
                               "578ebf8135336600054b0c00", # Chorus
                               "5b05d6a2cd3a6e039d9230e2", # RingDNA
                               "5b05d6cbcd3a6e039d9232e6" # BusyBusy
                             ])
    data = []

    companies.each do |company|
      users = company.campaigns.map { |c| c.user }.uniq { |u| u.id }

      users.each do |user|
        user_data = {}
        user_data["id"] = user.id
        user_data["email"] = user.email
        user_data["current_queue_profiles"] = Plugin::Fetchable.where(user_id: user.id, response_status: nil, :type.in => ["linkedin_user_profile", "linkedin_import_user_profile", "enhance_linkedin_user_profile"]).size
        user_data["current_queue_other"] = Plugin::Fetchable.where(user_id: user.id, response_status: nil, :type.nin => ["linkedin_user_profile", "linkedin_import_user_profile", "enhance_linkedin_user_profile"]).size
        user_data["fetched_profiles_day"] = Plugin::Fetchable.where(user_id: user.id, :fetched_at.gte => 24.hours.ago).size
        user_data["fetched_profiles_week"] = Plugin::Fetchable.where(user_id: user.id, :fetched_at.gte => 1.week.ago).size
        user_data["problem_fetchables"] = Plugin::Fetchable.where(user_id: user.id, :response_status.ne => nil, complete: false, :fetched_at.lte => 5.minutes.ago).size
        last_problem_fetchable = Plugin::Fetchable.where(user_id: user.id, :response_status.ne => nil, complete: false, :fetched_at.lte => 5.minutes.ago).order_by(fetched_at: :desc).limit(1)
        user_data["last_problem_fetchable"] = last_problem_fetchable.size > 0 ? last_problem_fetchable[0].id : nil
        last_fetchable = Plugin::Fetchable.where(user_id: user.id, :fetched_at.ne => nil, :type.in => ["linkedin_user_profile", "linkedin_import_user_profile", "enhance_linkedin_user_profile"]).order_by(fetched_at: :desc).limit(1).first
        user_data["last_fetchable"] = last_fetchable ? last_fetchable.id : nil
        user_data["last_fetchable_size"] = last_fetchable ? last_fetchable.response_body_size : nil
        user_data["last_fetchable_status"] = last_fetchable ? last_fetchable.response_status : nil
        user_data["last_fetchable_complete"] = last_fetchable ? last_fetchable.complete : nil
        last_seen = ExtensionStatusEvent.where(user_id: user.id).order_by(created_at: :desc).limit(1).first
        user_data["last_seen"] = last_seen ? last_seen.created_at : nil
        data.push(user_data)
      end
    end

    puts "id,email,last seen,queued profiles,queued cc,fetched 24hours, fetched 1 week,problem fetchables,last problem fetchable,last fetchable,last fetchable status, last fetchable response size, last fetchable complete"
    data.each do |d|
      puts "#{d["id"]},#{d["email"]},#{d["last_seen"]},#{d["current_queue_profiles"]},#{d["current_queue_other"]},#{d["fetched_profiles_day"]},#{d["fetched_profiles_week"]},#{d["problem_fetchables"]},#{d["last_problem_fetchable"]},#{d["last_fetchable"]},#{d["last_fetchable_size"]},#{d["last_fetchable_status"]},#{d["last_fetchable_complete"]}"
    end
  end
end
