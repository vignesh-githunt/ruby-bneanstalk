require 'rubygems'
require 'json'
require 'set'
require 'date'

INCLUDE_LOGS = !ENV['WITHOUT_LOGS']

namespace :embryo do
  CACHE_FILE = '/tmp/embryo-types.bin'
  task :rm do
    File.delete(CACHE_FILE)
  end

  task :build_types do
    # puts 'loading types...'
    # if File.file?(CACHE_FILE) and ENV['CACHE']
    #   puts "loading types from #{CACHE_FILE}..."
    #   File.open(CACHE_FILE) do |f|
    #     @types = Marshal.load(f)
    #   end
    # else
    #   puts 'loading types from raw dump...'
    #   @types = build_types "#{File.dirname(__FILE__)}/../../../devops/migrate"
    #   puts "saving types to #{CACHE_FILE}..."
    #   File.open(CACHE_FILE, 'w+') do |f|
    #     Marshal.dump @types, f
    #   end
    # end
    mw.perform(:build_types)
  end

  task :all => :environment do
    mw = Embryo::MigrationWorker.new
    mw.perform(:all)
  end #=> [
  #:users, :companies, :product_wizards, # existing hexa models
  #:sections, :action_definitions, :resource_definitions,
  #:resource_action_definitions, :resources, :resource_actions,
  #:resource_objects, :resource_object_properties,
  #:play_definitions, :play_executions, :opportunities, :logs
  # ]

  task :delete_all => :environment do
    # Section.delete_all
    # ActionDefinition.delete_all
    # ResourceDefinition.delete_all
    # ResourceActionDefinition.delete_all
    # Resource.delete_all
    # ResourceAction.delete_all
    # PlayDefinition.delete_all
    # PlayExecution.delete_all
    # Opportunity.delete_all
    # Log.delete_all if INCLUDE_LOGS
    mw = Embryo::MigrationWorker.new
    mw.perform(:delete_all)
  end

  # this one is dangerous
  task :delete_hexa => :environment do
    User.where(:embryo_id.exists => 1).and(roles_mask: nil).delete
    Company.where(isCustomer: true, :embryo_id.exists => 1, credits_remaining: 20).delete
    ProductWizard.where(:embryo_id.exists => 1).delete
  end

  task :users => [:environment, :build_types] do
    STDERR.puts ":users #{@types['User'].count}"
    @types['User'].each do |k, doc|
      doc.delete('_clients') # I don't think we need this
      doc.delete('auth0_user_id')
      doc.delete('nickname')

      doc['image_url'] = doc['picture']
      doc.delete('picture')

      if doc['name']
        name_parts = doc['name'].split
        doc['first_name'], doc['last_name'] = name_parts[0], name_parts[1]
        doc.delete('name')
      end

      # get completed valueNodes from Stamps
      if doc['_stamps']
        doc['_valueNodesCompleted'] = doc['_stamps'].map do |id|
          stamp = @types['Stamp'][id]
          stamp['_valueNode'][0] if stamp['_valueNode']
        end
        relate_many(doc, ResourceAction, 'resource_actions_completed_ids', '_valueNodesCompleted')
        doc.delete('_stamps')
      end

      relate_many(doc, PlayExecution, 'play_execution_ids', '_playExecutions')
      relate_many(doc, Log, 'log_ids', '_logs') if INCLUDE_LOGS
      upsert(doc, User)
    end
  end

  task :companies => [:environment, :build_types] do
    STDERR.puts ":companies #{@types['Client'].count}"
    @types['Client'].each do |k, doc|
      relate_many(doc, Opportunity, 'opportunities', '_opportunities')
      relate_many(doc, PlayExecution, 'play_execution_ids', '_plays')
      relate_many(doc, ProductWizard, 'product_wizard_ids', '_campaigns')
      doc['isCustomer'] = true
      upsert(doc, Company)
    end
  end

  task :product_wizards => [:companies, :environment, :build_types] do
    STDERR.puts ":product_wizards #{@types['Campaign'].count}"
    @types['Campaign'].each do |k, doc|
      relate(doc, Company, 'company_id', '_client')
      relate_many(doc, PlayExecution, 'play_execution_ids', '_plays')
      relate_many(doc, ResourceAction, 'resource_action_ids', '_valueNodes')
      relate_many(doc, Resource, 'resource_ids', '_values')
      relate_many(doc, Log, 'log_ids', '_logs') if INCLUDE_LOGS

      doc['product_name'] = doc['name']
      doc.delete('name')

      # these are not used
      doc.delete('_valueRelations')
      doc.delete('_valueNodeSyncs')
      doc.delete('_valueNodeStatusUpdates')
      doc.delete('customer_name')

      upsert(doc, ProductWizard)
    end
  end

  task :sections => [:environment, :build_types] do
    STDERR.puts ":sections #{@types['Section'].count}"
    @types['Section'].each do |k, doc|
      relate_many(doc, ResourceDefinition, 'resource_definition_ids', '_assets')
      upsert(doc, Section)
    end
  end

  task :action_definitions => [:environment, :build_types] do
    STDERR.puts ":action_definitions #{@types['Label'].count}"
    @types['Label'].each do |k, doc|
      relate_many(doc, ResourceAction, 'resource_action_ids', '_valueNodes')
      relate_many(doc, ResourceActionDefinition, 'resource_action_definition_ids', '_assetNodes')
      upsert(doc, ActionDefinition)
    end
  end

  task :resource_definitions => [:environment, :build_types] do # done
    STDERR.puts ":resource_definitions #{@types['Asset'].count}"
    @types['Asset'].each do |k, doc|
      doc['resource_type'] = doc['type']
      doc.delete('type')

      relate(doc, Section, 'section_id', '_section')
      relate_many(doc, Resource, 'resource_ids', '_values')
      relate_many(doc, ResourceActionDefinition, 'resource_action_definition_ids', '_nodes')
      upsert(doc, ResourceDefinition)
    end
  end

  task :resource_action_definitions => [:environment, :build_types] do
    STDERR.puts ":resource_action_definitions #{@types['AssetNode'].count}"
    @types['AssetNode'].each do |k, doc|
      relate(doc, ResourceDefinition, 'resource_definition_id', '_asset')
      relate(doc, ActionDefinition, 'action_definition_id', '_label')
      relate_many(doc, PlayDefinition, 'play_definition_ids', '_playDefinitions')
      relate_many(doc, ResourceAction, 'resource_action_ids', '_valueNodes')

      doc['workflow_role'] = doc['role']
      doc.delete('role')

      # collapse intermediate dependent relation models
      doc['dependent_ids'] = doc['_dependents'].map do |did|
        depId = @types['AssetRelation'][did]['_nodeA'][0]
        memoized_find_or_create_by(ResourceActionDefinition, depId)
      end if doc['_dependents']
      doc.delete('_dependents')

      # collapse intermediate dependency relation models
      doc['dependency_ids'] = doc['_dependencies'].map do |did|
        depId = @types['AssetRelation'][did]['_nodeB'][0]
        memoized_find_or_create_by(ResourceActionDefinition, depId)
      end if doc['_dependencies']
      doc.delete('_dependencies')

      upsert(doc, ResourceActionDefinition)
    end
  end

  task :resources => [:environment, :build_types] do
    STDERR.puts ":resources #{@types['Value'].count}"
    @types['Value'].each do |k, doc|
      doc.delete('status')

      doc['string_value'] = doc['string']
      doc.delete('string')

      relate(doc, ResourceDefinition, 'resource_definition_id', '_asset')
      relate(doc, PlayExecution, 'play_execution_id', '_playExecution')
      relate(doc, ProductWizard, 'product_wizard_id', '_campaign')

      relate_many(doc, ResourceAction, 'resource_action_ids', '_nodes')
      relate_many(doc, Log, 'log_ids', '_logs') if INCLUDE_LOGS

      # embed the value objects
      doc['objects'] = doc['_objects'].map do |oid|
        obj = @types['ValueObject'][oid]
        obj['properties'] = obj['_fields'].map do |fid|
          prop = @types['ValueObjectField'][fid]
          prop.delete('_object')
          prop
        end
        obj.delete('_fields')
        obj.delete('_value')
        obj
      end if doc['_objects']
      doc.delete('_objects')

      upsert(doc, Resource)
    end
  end

  task :resource_objects => [:environment, :build_types] do
    STDERR.puts ":resource_objects #{@types['ValueObject'].count}"
  end

  task :resource_object_properties => [:environment, :build_types] do
    STDERR.puts ":resource_object_properties #{@types['ValueObjectField'].count}"
  end

  task :resource_actions => [:users, :environment, :build_types] do
    STDERR.puts ":resource_actions #{@types['ValueNode'].count}"
    @types['ValueNode'].each do |k, doc|
      relate(doc, ResourceActionDefinition, 'resource_action_definition_id', '_assetNode')
      relate(doc, PlayExecution, 'play_execution_id', '_playExecution')
      relate(doc, ProductWizard, 'product_wizard_id', '_campaign')
      relate(doc, Resource, 'resource_id', '_value')

      # collapse intermediate dependent relation models
      doc['dependent_ids'] = doc['_dependents'].map do |did|
        depId = @types['ValueRelation'][did]['_nodeA'][0]
        memoized_find_or_create_by(ResourceAction, depId)
      end if doc['_dependents']
      doc.delete('_dependents')

      # collapse intermediate dependency relation models
      doc['dependency_ids'] = doc['_dependencies'].map do |did|
        depId = @types['ValueRelation'][did]['_nodeB'][0]
        memoized_find_or_create_by(ResourceAction, depId)
      end if doc['_dependencies']
      doc.delete('_dependencies')

      # we removed the Stamp model, but need data from it
      if (doc['_stamp'])
        stamp = @types['Stamp'][doc['_stamp'][0]]
        doc['completed_at'] = stamp['created_at']
        doc['_stampCreatedBy'] = stamp['_createdBy']
        relate(doc, User, 'completed_by_id', '_stampCreatedBy')
        doc.delete('_stamp')
      end

      # embed Action
      label = @types['Label'][doc['_label'][0]]
      action = {
        'embryo_id' => label['embryo_id'],
        'name' => label['name'],
        'color' => label['color'],
        'updated_at' => label['updated_at'],
        'created_at' => label['created_at'],
        '_actionDefinition' => label['embryo_id']
      }
      relate(action, ActionDefinition, 'action_definition_id', '_actionDefinition')
      doc['action'] = action
      doc.delete('_label')

      upsert(doc, ResourceAction)
    end
  end

  task :play_definitions => [:environment, :build_types] do
    STDERR.puts ":play_definitions #{@types['PlayDefinition'].count}"
    @types['PlayDefinition'].each do |k, doc|
      doc['play_type'] = doc['type']
      doc.delete('type')

      relate_many(doc, ResourceActionDefinition, 'resource_action_definition_ids', '_assetNodes')
      doc.delete('_assetRelationships')
      upsert(doc, PlayDefinition)
    end
  end

  task :play_executions => [:users, :environment, :build_types] do
    STDERR.puts ":play_executions #{@types['PlayExecution'].count}"
    @types['PlayExecution'].each do |k, doc|
      relate(doc, PlayDefinition, 'play_definition_id', '_playDefinition')
      relate(doc, ProductWizard, 'product_wizard_id', '_campaign')
      relate(doc, Company, 'company_id', '_client')
      relate(doc, User, 'user_id', '_createdBy')
      relate_many(doc, Resource, 'resource_ids', '_values')
      relate_many(doc, ResourceAction, 'resource_action_ids', '_valueNodes')
      upsert(doc, PlayExecution)
    end
  end

  task :opportunities => [:users, :environment, :build_types] do
    STDERR.puts ":opportunities #{@types['Opportunity'].count}"
    @types['Opportunity'].each do |k, doc|
      relate(doc, Company, 'customer_id', '_client')
      relate(doc, User, 'created_by', '_createdBy')
      relate(doc, Log, 'log_id', '_logs') if INCLUDE_LOGS

      upsert(doc, Opportunity)
    end
  end

  task :logs => [:users, :environment, :build_types] do
    if INCLUDE_LOGS
      STDERR.puts ":logs #{@types['Log'].count}"
      @types['Log'].each do |k, doc|
        relate(doc, ProductWizard, 'product_wizard_id', '_campaign')
        relate(doc, User, 'user_id', '_user')
        relate(doc, Resource, 'resource_id', '_value')
        relate(doc, Opportunity, 'opportunity_id', '_opportunity')

        upsert(doc, Log)
      end
    end
  end
end

def build_types dir
  type_names = Set[]
  types = {}

  puts "building nodes..."
  File.directory?("#{dir}/nodes") or raise "no nodes found"

  Dir["#{dir}/nodes/*.json"].sort.each do |f|
    j = read_json f
    j['values'].each do |model|
      n = model['_typeName']
      type_names.add n
      id = model['id']
      types[n] or types[n] = {}
      doc = {}
      doc['embryo_id'] = model['id']
      model.except('id', '_typeName').each { |k, v| doc[k.underscore] = v }
      types[n][id] = doc
    end
  end

  puts "building relations..."
  File.directory?("#{dir}/relations") or raise "no relations found"

  Dir["#{dir}/relations/*.json"].sort.each do |f|
    j = read_json f
    j['values'].each do |v|
      t = [
        types[v[0]['_typeName']][v[0]['id']],
        types[v[1]['_typeName']][v[1]['id']]
      ]
      t[0]["_#{v[0]['fieldName']}"] ||= []
      t[1]["_#{v[1]['fieldName']}"] ||= []

      t[0]["_#{v[0]['fieldName']}"] << t[1]['embryo_id']
      t[1]["_#{v[1]['fieldName']}"] << t[0]['embryo_id']
    end
  end

  # type_names.each do |n| puts "#{types[n].count}\t#{n}" end

  types
end

def read_json file_name
  file = File.open(file_name, "r")
  data = file.read
  JSON.parse(data)
end

@memo = {}
def memoized_find_or_create_by model, embryo_id
  if @memo[embryo_id]
    puts "HIT"
    @memo[embryo_id]
  else
    puts "MISS"
    result = model.collection.find(embryo_id: embryo_id).first
    if result
      doc_id = result['_id']
    else
      doc_id = model.collection.insert_one(embryo_id: embryo_id).inserted_id
    end

    @memo[embryo_id] = doc_id
  end
end

def relate doc, model, field, embryo_field
  if doc[embryo_field]
    doc[field] = memoized_find_or_create_by(model, doc[embryo_field][0])
    doc.delete(embryo_field)
  end
end

def relate_many doc, model, field, embryo_field
  if doc[embryo_field]
    doc[field] = doc[embryo_field].map do |eid|
      memoized_find_or_create_by(model, eid)
    end
    doc.delete(embryo_field)
  end
end

def upsert doc, model
  model.fields.each do |k, v|
    if v.type == Time or v.type == DateTime or v.type == Date
      doc[k] = DateTime.parse doc[k] rescue nil
    end
  end

  model.collection.update_one({ embryo_id: doc['embryo_id'] }, { "$set": doc }, { upsert: true })
end
