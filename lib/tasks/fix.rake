def raise_unless_confirmed
  unless ENV['CONFIRM'] == '1'
    raise "missing CONFIRM=1"
  end
end

namespace :fix do
  desc "set booleans to proper values"
  # arguments: model_name field_name
  # usage: bundle exec rake fix:booleans ProductWizard active
  task booleans: :environment do
    ARGV.each { |a| task a.to_sym do; end }
    model = ARGV[1].safe_constantize
    field = ARGV[2].to_sym

    model.where(field.in => [true, "true", 1, "1"]).update_all({ field => true })
    model.where(field.in => [false, "false", 0, "0"]).update_all({ field => false })
  end

  desc "set leads with email_status 0 to 10 in campaigns created in last 90 days"
  task email_status: :environment do
    campaigns = Campaign.where(:lead_list_file_url.ne => nil, :updated_at.gte => Time.now - 90.days)
    campaigns.each do |c|
      STDERR.puts "#{c.name} #{c.lead_list.users.map(&:email_status)}"
      users = c.lead_list.users.where(email_status: 0)
      users.update_all(email_status: 10)
    end
  end

  desc "change fetchables to the right queue owner"
  task change_fetchable_queue_owner: :environment do
    u1 = User.find_by(email: ENV['from_email'])
    u2 = User.find_by(email: ENV['to_email'])
    fs = FetchableService.new
    u1_queue_size = fs.queue_size(u1._id)
    puts "u1 queue_size = #{u1_queue_size}"
    if u1_queue_size > 0
      fetchables = Plugin::Fetchable.where(user_id: u1._id, response_status: nil).to_a
      fetchables.each do |f|
        f.update_attribute(:user_id, u2._id)
      end
      puts "u2 queue_size = #{fs.queue_size(u2._id)}"
      u2.send_message_to_plugin("minables-updated")
    end
  end

  desc "set fetchables completed_at to updated_at where complete is true and completed_at is nil"
  task update_completed_at: :environment do
    count = 1
    loop do
      fetchables = Plugin::Fetchable
                   .where(complete: true, completed_at: nil, :updated_at.ne => nil)
                   .limit(ENV['LIMIT'].to_i)

      break if fetchables.size == 0

      raise_unless_confirmed

      begin
        fetchables.each do |f|
          f.set(completed_at: f.updated_at)
          puts count
          count += 1
        end
      rescue
        EventLog.warn("Error trying to update fetchable", event: :fix_fetchable_completed_at)
      end

      sleep(ENV['SLEEP'].to_i)
    end

    EventLog.info "Completed setting fetchable completed_at to updated_at", event: :fix_fetchable_completed_at
  end

  desc "fix fetchable common connection urls"
  task common_connection_urls: :environment do
    fetchables = Plugin::Fetchable.where(type: "linkedin_connections_data", complete: false, url: /linkedin\.com\/pub\/.+\/highlights$/i)
    fetchables.each do |fetchable|
      begin
        profile_url = fetchable.url.sub(/\/highlights$/i, "") # revert url back to profile url
        common_connections_url = create_common_connections_url(profile_url) # build correct url
        puts "#{fetchable.url} - #{common_connections_url}"
        if !common_connections_url
          puts "Error - Unable to create new common connections url"
        elsif ENV['CONFIRM'] == '1'
          fetchable.set(url: common_connections_url, response_status: nil, response_body_filename: nil)
        end
      rescue
        puts "Error trying to fix fetchable " + fetchable.url
      end
    end

    fetchables = Plugin::Fetchable.where(type: "linkedin_connections_data", complete: false, url: /linkedin\.com\/voyager\/api\/identity\/profiles\/[\w|-]+\/\?.+\/highlights/i)
    fetchables.each do |fetchable|
      begin
        profile_url = fetchable.url.sub(/\/highlights$/i, "") # revert url back to profile url
        profile_url = profile_url.sub(/voyager\/api\/identity\/profiles/i, "in")
        common_connections_url = create_common_connections_url(profile_url) # build correct url
        puts "#{fetchable.url} - #{common_connections_url}"
        if !common_connections_url
          puts "Error - Unable to create new common connections url"
        elsif ENV['CONFIRM'] == '1'
          fetchable.set(url: common_connections_url, response_status: nil, response_body_filename: nil)
        end
      rescue
        puts "Error trying to fix fetchable " + fetchable.url
      end
    end
  end

  def create_common_connections_url(fetchable_url)
    profile_identifier = nil
    url_with_connections_data = nil
    public_li_url_re = /linkedin\.com\/pub\//i
    standard_li_url_re = /linkedin\.com\/in\//i
    public_li_url_identifier_re = /linkedin\.com\/pub\/([\w|\-|%]*)\/?/i
    public_li_url_identifier_two_re = /\/(\w{1,3})\/(\w{1,3})\/(\w{1,3})\/?/i
    standard_li_url_identifier_re = /linkedin\.com\/in\/([\w|-]*)\/?/i

    if (public_li_url_re.match(fetchable_url))
      profile_identifier = public_li_url_identifier_re.match(fetchable_url)[1]
      if (public_li_url_identifier_two_re.match(fetchable_url))
        identifier_match = fetchable_url.match(public_li_url_identifier_two_re)
        profile_identifier += "-#{identifier_match[3]}#{identifier_match[2]}#{identifier_match[1]}"
      end
    elsif (standard_li_url_re.match(fetchable_url))
      identifier_match = fetchable_url.match(standard_li_url_identifier_re)
      profile_identifier = identifier_match[1]
    end

    if (profile_identifier)
      url_with_connections_data = "https://www.linkedin.com/voyager/api/identity/profiles/#{profile_identifier}/highlights"
    end
  end

  namespace :campaigns do
    desc "delete many campaigns and dependent data (pass IDS via environment)"
    # rake fix:campaigns:delete IDS="H476oBM9qwnYxDyxm 5c8ju59YuNYopb4xJ vAMQDAzKDHcN3bTQD"
    task :delete => :environment do
      ids = ENV["IDS"]
      raise "missing IDS" unless ids

      ids.split.each do |id|
        remove_campaign id
      end
    end

    def remove_campaign id
      begin
        fetchables = Plugin::Fetchable.where(campaign_id: id)
        STDERR.puts "FETCHABLES", fetchables.count, fetchables.first.inspect
        fetchables.each do |f|
          f.destroy!
        end
      rescue => e
        EventLog.error "problem destroying fetchables for campaign #{id}", event: :fix_remove_campaign, exception: e
      end

      begin
        raw_leads = RawLead.where(campaign_id: id)
        STDERR.puts "RAW_LEADS", raw_leads.count, raw_leads.first.inspect
        raw_leads.each do |l|
          l.destroy!
        end
      rescue => e
        EventLog.error "problem destroying raw_leads for campaign #{id}", event: :fix_remove_campaign, exception: e
      end

      begin
        campaign = Campaign.find(id: id)
        STDERR.puts campaign.inspect
        campaign.destroy!
      rescue => e
        EventLog.error "problem destroying campaign #{id}", event: :fix_remove_campaign, exception: e
      end
    end
  end

  namespace :companies do
    desc "Merge Users, PlayExecutions, ProductWizards and Plugins from companies in SOURCE_ID to TARGET_ID"
    task :merge => :environment do
      source_id = ENV['SOURCE_ID']
      target_id = ENV['TARGET_ID']

      raise "missing SOURCE_ID" unless source_id
      raise "missing TARGET_ID" unless target_id

      source = Company.find(source_id)
      target = Company.find(target_id)

      expected_counts = {
        users: source.users.count + target.users.count,
        play_executions: source.play_executions.count + target.play_executions.count,
        product_wizards: source.product_wizards.count + target.product_wizards.count,
        plugins: source.get_plugins.count + target.get_plugins.count
      }

      # move everything from source to target
      [
        User,
        PlayExecution,
        ProductWizard,
        Plugin
      ].each do |model|
        model.where(company_id: source.id)
             .update_all(company_id: target.id)
      end

      ### assert everything adds up
      source.reload
      target.reload

      raise unless source.users.count           == 0
      raise unless source.play_executions.count == 0
      raise unless source.product_wizards.count == 0
      raise unless source.get_plugins.count     == 0

      raise unless target.users.count           == expected_counts[:users]
      raise unless target.play_executions.count == expected_counts[:play_executions]
      raise unless target.product_wizards.count == expected_counts[:product_wizards]
      raise unless target.get_plugins.count     == expected_counts[:plugins]
    end
  end

  namespace :fetchables do
    desc "add response_body_filenames and metadata fetchables"
    task filename_and_metadata: :environment do
      limit = ENV['LIMIT'].to_i
      limit = nil if limit.zero?
      fetchables = Plugin::Fetchable.where({ :tmp_response_body_fixed.ne => true }).limit(limit).no_timeout
      count = limit || fetchables.count
      puts "about to process #{count} fetchables"

      start = Time.new
      fetchables.each_with_index do |f, i|
        if (i % 100) == 0
          # output some timing information to get an estimated time to completion
          elapsed = Time.new - start
          per_s = (i / elapsed).round(2)
          remaining_s = per_s > 0 ? ((count - i) / per_s).round : 0
          remaining_h = (remaining_s.to_f / (60 * 60)).round(1)
          etc = Time.new + remaining_s
          STDERR.puts "#{i}/#{count}: #{((i / count.to_f) * 100).round(1)}% #{per_s}/s e:#{elapsed.round}s r:#{remaining_h}h etc:#{etc} - #{f.id} s:#{f.response_status} (#{f.response_body_filename})"
        end

        # update fetchable fields if there is a file in cloud storage
        file = GoogleBucket.instance.file f.id
        if file
          # STDERR.puts "update response_body_file #{file.name} #{file.size} #{file.md5} #{file.created_at}"
          f.set(response_body_filename: file.name,
                response_body_size: file.size,
                response_body_md5: file.md5,
                fetched_at: file.created_at)
        end
        f.set(tmp_response_body_fixed: true)
      end
    end
  end
end
