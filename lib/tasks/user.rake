namespace :user do
  namespace :export do
    desc "rough sample"
    task sample: :environment do
      File.open("output.json", "w") do |file|
        file.puts "["
        first = true
        User.where(roles_mask: 16).limit(1000).order(created_at: 1).each do |user|
          if first
            first = false
          else
            file.puts ","
          end

          hash = user.attributes.without("settings", "encrypted_password", "sign_in_count", "workflow_roles", "confirmed_at", "confirmation_sent_at", "current_sign_in_at", "last_sign_in_ip", "last_sign_in_at", "force_cache", "current_campaign_id")
          user.to_data_points.each do |point|
            hash[point.type] = point.value
          end
          file.puts hash.to_json
        end

        file.puts "]"
      end

      # convert to csv

      @headers = []
      file = File.open('output.json')
      JSON.parse(file.read).each do |h|
        h.keys.each do |key|
          @headers << key
        end
      end

      uniq_headers = @headers.uniq
      file = File.open('output.json')
      finalrow = []

      JSON.parse(file.read).each do |h|
        final = {}
        @headers.each do |key2|
          final[key2] = h[key2]
        end

        finalrow << final
      end

      CSV.open('output.csv', 'w') do |csv|
        csv << uniq_headers
        finalrow.each do |deal|
          csv << deal.values
        end
      end
    end
  end
end
