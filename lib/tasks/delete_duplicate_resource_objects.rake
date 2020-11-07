def logerr str; STDERR.puts str; end

namespace :db do
  desc "Delete duplicate resource value objects"
  task delete_duplicate_resource_objects: :environment do
    logerr "Just testing"

    # find the resources that have at least 2 objects
    resources = Resource.collection.find({ "objects.1" => { "$exists" => true } })

    logerr "Checking #{resources.count} resources"

    count = 0

    resources.each do |resource|
      resource[:objects].group_by { |o| o[:embryo_id] }.each do |k, objects|
        if objects.length > 1 and objects[0][:embryo_id]
          # objects here contain more than one record with the same embryo_id

          uniq_property_values = objects.map { |o| o[:properties].pluck(:value) }.uniq

          if uniq_property_values.count > 1
            logerr "############# NOT DELETING: MANUALLY INSPECT THIS RESOURCE #############"
            logerr "# resource: #{resource[:_id]}"
            logerr "# objects: #{objects.inspect}"
            logerr "########################################################################"
          else
            # the property values for each object are all the same, so
            # we can safely delete all but one of them
            keep = objects[0]
            delete = objects.drop(1)

            logerr "resource: #{resource[:_id]}"
            logerr "keep: #{keep}\n"
            logerr "delete: #{delete}"

            if ENV["DELETE"]
              ids_to_delete = delete.map { |d| d[:_id] }
              logerr "DELETING OBJECT IDS: #{ids_to_delete}"
              crit = Resource.find(resource[:_id]).objects.where(:id.in => ids_to_delete)
              count += crit.count
              crit.delete
            end
          end
          logerr "---"
        end
      end
    end

    logerr "total deleted objects #{count}"
  end
end
