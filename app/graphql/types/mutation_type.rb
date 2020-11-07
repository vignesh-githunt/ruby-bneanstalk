Types::MutationType = GraphQL::ObjectType.define do
  name "Mutation"

  Graphoid::Models.all.each do |model|
    Graphoid::Mutations::Create.new(model, self)
    Graphoid::Mutations::Update.new(model, self)
    Graphoid::Mutations::Delete.new(model, self)
  end

  field :updateV3_Customer_StoryComponents_Elements_ValueTriggered do
    mongo_model = V3::Customer::StoryComponents::Elements::ValueTriggered
    type Graphoid.get(mongo_model).type
    graphoid_model = Graphoid.get(mongo_model)

    argument :id, !types.ID
    argument :data, graphoid_model.mutation

    resolve ->(obj, args, ctx) do
      begin
        return GraphQL::ExecutionError.new("insuficient permission") unless Graphoid::Auth.check(ctx, mongo_model, :update)

        args = args.to_h
        id = args["id"]
        fields = Graphoid::Utils.fieldnames_of(mongo_model)
        attrs = Graphoid::Utils.underscore(args["data"], fields)
        dataPoints = attrs.delete("trigger_data_points")
        # automatically set updated_by field
        attrs['updated_by_id'] = ctx[:current_user].id if fields.include?('updated_by_id')

        result = mongo_model.find(id).update!(attrs)
        result = mongo_model.find(id)
        dataPoints.each do |dp|
          dp_type = "V3::Data::DataPoints::#{dp["dataPointType"]}"
          data_point = result.trigger_data_points.where(_type: dp_type).first
          if (data_point)
            data_point.value = dp["value"]
            data_point.save!
            result.save!
          else
            # new data point
            result.trigger_data_points.new({ value: dp["value"], data_source: V3::Data::DataSource::OUTBOUNDWORKS }, dp_type.constantize)
            result.save!
          end
        end
        result
      rescue Exception => e
        GraphQL::ExecutionError.new(e.message)
      end
    end
  end

  field :updateV3_Customer_StoryComponents_Elements_TypeTriggered do
    mongo_model = V3::Customer::StoryComponents::Elements::TypeTriggered
    type Graphoid.get(mongo_model).type
    graphoid_model = Graphoid.get(mongo_model)

    argument :id, !types.ID
    argument :data, graphoid_model.mutation

    resolve ->(obj, args, ctx) do
      begin
        return GraphQL::ExecutionError.new("insuficient permission") unless Graphoid::Auth.check(ctx, mongo_model, :update)

        args = args.to_h
        id = args["id"]
        fields = Graphoid::Utils.fieldnames_of(mongo_model)

        attrs = Graphoid::Utils.underscore(args["data"], fields)
        dataPoints = attrs.delete("trigger_data_points")
        puts dataPoints

        puts "#################"

        puts attrs
        # automatically set updated_by field
        attrs['updated_by_id'] = ctx[:current_user].id if fields.include?('updated_by_id')

        result = mongo_model.find(id).update!(attrs)
        result = mongo_model.find(id)
        dataPoints.each do |dp|
          dp_type = "V3::Data::DataPoints::#{dp["dataPointType"]}"
          data_point = result.trigger_data_points.where(_type: dp_type).first
          if (data_point)
            data_point.save!
            result.save!
          else
            # new data point
            result.trigger_data_points.new({ data_source: V3::Data::DataSource::OUTBOUNDWORKS }, dp_type.constantize)
            result.save!
          end
        end
        result
      rescue Exception => e
        GraphQL::ExecutionError.new(e.message)
      end
    end
  end

  # we are overriding this creation method because mongoid converts
  # the file field to string and we cannot get the ruby file object back
  # to make it work on a before_save callback

  field :login do
    graphoid_model = Graphoid.get(User)
    type graphoid_model.type
    description "Login for users"
    argument :email, types.String
    argument :password, types.String
    resolve ->(obj, args, ctx) do
      user = User.find_for_authentication(email: args.email)
      return nil if !user

      is_valid_for_auth = user.valid_for_authentication? {
        user.valid_password?(args.password)
      }
      reload_token = user.set_jit_token
      return is_valid_for_auth ? user : nil
    end
  end

  field :reset_password do
    type types.Boolean
    description "Set the new Password"
    argument :password, types.String
    argument :password_confirmation, types.String
    argument :reset_password_token, types.String
    resolve ->(obj, args, ctx) do
      user = User.with_reset_password_token(args.reset_password_token)
      puts " hi #{user.first_name}"
      return false if !user

      user.reset_password(args.password, args.password_confirmation)
      true
    end
  end
  field :update_user do
    graphoid_model = Graphoid.get(User)
    type graphoid_model.type
    description "Update user"
    argument :password, types.String
    argument :password_confirmation, types.String
    resolve ->(obj, args, ctx) do
      user = ctx[:current_user]
      return nil if !user

      user.update!(
        password: args.password,
        password_confirmation: args.password_confirmation
      )
      user
    end
  end

  field :reset_password_instructions do
    type types.Boolean
    description "Send password reset instructions to users email"
    argument :email, types.String

    resolve ->(obj, args, ctx) do
      user = User.find_by(email: args.email)
      return false if !user

      user.send_reset_password_instructions
      true
    end
  end

  field :logout do
    type types.Boolean
    description "Logout for users"
    resolve ->(obj, args, ctx) do
      if ctx[:current_user]
        ctx[:current_user].update(jti: SecureRandom.uuid)
        return true
      end
      false
    end
  end
  field :createDoNotContactList do
    graphoid_model = Graphoid.get(DoNotContactList)

    type graphoid_model.type
    argument :data, graphoid_model.mutation

    resolve ->(obj, args, ctx) do
      file = args["data"]["file"]

      attributes = {
        name: args["data"]["name"],
        created_by: ctx[:current_user],
        company_id: args["data"]["companyId"]
      }

      refresh_hours = args["data"]["scheduledRefreshHours"]
      attributes[:scheduled_refresh_hours] = refresh_hours if refresh_hours.present?

      slfc_report_id = args["data"]["salesForceReportId"]
      attributes[:sales_force_report_id] = slfc_report_id if slfc_report_id.present?

      begin
        dncl = DoNotContactList.new(attributes)

        if file
          dncl.file_source = file
          dncl.upload(file.original_filename, file.tempfile)
        end

        dncl.save!
        dncl
      rescue Exception => e
        GraphQL::ExecutionError.new(e.summary)
      end
    end
  end

  field :createManifest do
    graphoid_model = Graphoid.get(Manifest)

    type graphoid_model.type
    argument :data, graphoid_model.mutation

    resolve ->(obj, args, ctx) do
      customer_id = args["data"]["customerId"]
      name = args["data"]["name"]
      queue_owner_id = args["data"]["queueOwnerId"]
      sequence_id = args["data"]["sequenceId"]
      l2_sequence_id = args["data"]["l2SequenceId"]
      sequencer_type = args["data"]["sequencerType"]
      l2_sequencer_type = args["data"]["l2SequencerType"]
      enhance_with_linkedin = args["data"]["enhanceWithLinkedin"]
      cohort_size = args["data"]["cohortSize"]
      import_file_url = args["data"]["file"]
      cohort_keywords = args["data"]["cohortKeywords"]
      paused_at = args["data"]["pausedAt"]

      manifest = Manifest.new(
        customer_id: customer_id,
        name: name,
        queue_owner_id: queue_owner_id,
        sequence_id: sequence_id,
        sequencer_type: sequencer_type,
        l2_sequence_id: l2_sequence_id,
        l2_sequencer_type: l2_sequencer_type,
        enhance_with_linkedin: enhance_with_linkedin,
        cohort_size: cohort_size,
        cohort_keywords: cohort_keywords,
        paused_at: paused_at
      )

      manifest.upload(import_file_url.original_filename, import_file_url.tempfile) if import_file_url
      manifest.save!

      manifest
    end
  end

  field :createDiscoverorgImportDelivery do
    graphoid_model = Graphoid.get(Warehouse::DiscoverorgImportDelivery)
    # puts "#################################### #{graphoid_model}"
    type graphoid_model.type
    argument :data, graphoid_model.mutation

    resolve ->(obj, args, ctx) do
      customer_id = args["data"]["customerId"]
      name = args["data"]["name"]
      keywords = args["data"]["keywords"]
      import_file_url = args["data"]["file"]
      data_source = args["data"]["dataSource"]
      priority = args["data"]["priority"]

      case data_source
      when Warehouse::Delivery::DataSource::DISCOVERORG, Warehouse::Delivery::DataSource::DISCOVERORGTECH
        delivery = Warehouse::DiscoverorgImportDelivery.new(
          customer_id: customer_id,
          name: name,
          keywords: keywords,
          data_source: data_source,
          priority: priority
        )
      when Warehouse::Delivery::DataSource::ZOOMINFO
        delivery = Warehouse::ZoominfoImportDelivery.new(
          customer_id: customer_id,
          name: name,
          keywords: keywords,
          priority: priority
        )
      when Warehouse::Delivery::DataSource::GENERIC
        delivery = Warehouse::CsvImportDelivery.new(
          customer_id: customer_id,
          name: name,
          keywords: keywords,
          priority: priority
        )
      end

      # if file
      #   #delivery.file_source = file
      #   delivery.upload(file.original_filename, file.tempfile)
      # end
      delivery.upload(import_file_url.original_filename, import_file_url.tempfile) if import_file_url
      delivery.save!

      delivery
    end
  end

  field :createCsvDataProvider do
    graphoid_model = Graphoid.get(V3::Import::CsvDataProvider)
    # puts "#################################### #{graphoid_model}"
    type graphoid_model.type
    argument :data, graphoid_model.mutation

    resolve ->(obj, args, ctx) do
      # customer_id = args["data"]["customerId"]
      # keywords = args["data"]["keywords"]
      import_file = args["data"]["file"]
      data_source = args["data"]["dataSource"]
      data_types = args["data"]["dataTypes"]
      # tags = args["data"]["tags"]
      # priority = args["data"]["priority"]

      provider = V3::Import::CsvDataProvider.new(
        data_source: data_source,
        data_types: data_types,
        tags: ["CSV", "Upload"]
      )

      provider.upload(import_file.original_filename, import_file.tempfile) if import_file
      # find out how many rows are in the csv file
      content = File.read(import_file.tempfile)
      content.gsub!("\xEF\xBB\xBF", '')
      encoded_content = content.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "")
      my_csv = CSV.new(encoded_content, { headers: :first_row, encoding: 'utf-8' })

      provider.size = my_csv.readlines.size
      # todo: improve this by just using file instead
      provider.save!

      provider
    end
  end

  field :createV3_Customer_AccountAssignmentLogic do
    graphoid_model = Graphoid.get(V3::Customer::AccountAssignmentLogic)

    type graphoid_model.type
    argument :data, graphoid_model.mutation

    resolve ->(obj, args, ctx) do
      customer_id = args["data"]["customerId"]
      name = args["data"]["name"]

      aal = V3::Customer::AccountAssignmentLogic.new(
        customer_id: customer_id,
        name: name
      )

      aal.priority = args["data"]["priority"] if args["data"]["priority"]

      aal.build_rule_set(evaluation_logic: "any")
      aal.save!
      aal
    end
  end

  field :createAccountsProfile do
    argument :customerId, types.ID
    argument :modelId, types.ID
    argument :_type, types.String
    graphoid_model = Graphoid.get(AccountsProfile)
    type graphoid_model.type

    resolve ->(obj, args, ctx) do
      customer_id = args["customerId"]
      _type = args["_type"]
      model_id = args["modelId"]

      customer = Company.find(customer_id)
      # Todo: refactor this to do _type.classify.send(:from_model, customer, model)
      case _type
      when "WarehouseAccountsProfile"
        warehouse = customer.warehouse
        ap = WarehouseAccountsProfile.from_model(customer, warehouse)
      when "ManifestAccountsProfile"
        manifest = Manifest.find(model_id)
        ap = ManifestAccountsProfile.from_model(customer, manifest)
      when "CohortAccountsProfile"
        cohort = Campaign.find(model_id)
        ap = CohortAccountsProfile.from_model(customer, cohort)
      when "OutcomesAccountsProfile"
        ap = OutcomesAccountsProfile.from_model(customer)
      when "DeliveryAccountsProfile"
        delivery = Warehouse::Delivery.find(model_id)
        ap = DeliveryAccountsProfile.from_model(customer, delivery)
      end

      ap
    end
  end

  field :addDependency do
    type Graphoid.get(ResourceActionDefinition).type

    argument :parent, types.ID
    argument :child, types.ID

    resolve ->(obj, args, ctx) do
      parent = ResourceActionDefinition.find(args["parent"])
      child = ResourceActionDefinition.find(args["child"])

      begin
        parent.prevent_cycle(parent.dependencies + [child])
        parent.dependencies.push(child)

        child.reload
      rescue Exception => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :removeDependency do
    type Graphoid.get(ResourceActionDefinition).type

    argument :parent, types.ID
    argument :child, types.ID

    resolve ->(obj, args, ctx) do
      parent = ResourceActionDefinition.find(args["parent"])
      child = ResourceActionDefinition.find(args["child"])
      parent.dependencies.delete(child)

      child.reload
    end
  end

  field :startPlays do
    argument :playsIds, types[types.ID]
    argument :productWizardId, types.ID
    argument :comment, types.String
    type types[Graphoid.get(PlayExecution).type]
    resolve ->(obj, args, ctx) do
      play_list = []
      company = ctx[:current_user].company
      user = ctx[:current_user]

      product_wizard = ProductWizard.find(args['productWizardId'])
      play_list = product_wizard.start_play(args["playsIds"], company, args['comment'], user)
    end
  end

  field :pushResourceAction do
    argument :resourceActionId, types.ID
    argument :days, types.Int
    argument :comment, types.String
    type Graphoid.get(ResourceAction).type
    resolve ->(obj, args, ctx) do
      resource_action = ResourceAction.find(args['resourceActionId'])
      resource_action.push_back(args['days'], args['comment'])
      resource_action
    end
  end

  field :clearPushResourceAction do
    argument :resourceActionId, types.ID
    type Graphoid.get(ResourceAction).type
    resolve ->(obj, args, ctx) do
      resource_action = ResourceAction.find(args['resourceActionId'])
      resource_action.clear_push_back
      resource_action
    end
  end

  field :syncPlaysAction do
    type types.String
    resolve ->(obj, args, ctx) do
      begin
        PlayDefinition.synchronise_all_plays
        return "done"
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :addDoNotContactAccount do
    argument :doNotContactListId, types.ID
    argument :companyName, types.String
    argument :domain, types.String
    type types.String

    resolve ->(obj, args, ctx) do
      begin
        dnc_list = DoNotContactList.find(args['doNotContactListId'])
        DoNotContactAccount.enhance(args['companyName'], args['domain'], dnc_list)
        return "done"
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :removeDoNotContactAccount do
    type Graphoid.get(DoNotContactAccount).type
    argument :doNotContactListId, types.ID
    argument :id, types.ID

    resolve ->(obj, args, ctx) do
      begin
        dnc_list = DoNotContactList.find(args['doNotContactListId'])
        dnc_account = dnc_list.do_not_contact_accounts.find(args['id'])
        dnc_account.do_not_contact_list = dnc_list
        dnc_account.destroy

        dnc_account
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :dispatchFetchable do
    argument :id, !types.ID
    type types.ID
    resolve ->(obj, args, ctx) do
      begin
        Plugin::Fetchable.find(args['id']).dispatch
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :resetFetchable do
    argument :id, !types.ID
    type types.Boolean
    resolve ->(obj, args, ctx) do
      begin
        Plugin::Fetchable.find(args['id']).reset!
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :refreshSequences do
    argument :userId, types.ID
    type types.Boolean
    resolve ->(obj, args, ctx) do
      begin
        return [] if args['userId'].empty?

        user = User.find(args['userId'])
        outreach_plugin = OutreachPlugin.where(company_id: user.company_id).first
        outreach_plugin&.sequences(user, true)
        salesloft_plugin = SalesloftPlugin.where(company_id: user.company_id).first
        salesloft_plugin&.sequences(user, true)
        connectleader_plugin = ConnectleaderPlugin.where(company_id: user.company_id).first
        connectleader_plugin&.sequences(user, true)
        mixmax_plugin = MixmaxPlugin.where(company_id: user.company_id).first
        mixmax_plugin&.sequences(user, true)
        true
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :createContactProvider do
    graphoid_model = Graphoid.get(ContactProvider)
    argument :data, graphoid_model.mutation
    argument :deliveryIds, types[types.ID]
    argument :selectedSenderIds, types[types.ID]
    type graphoid_model.type
    resolve ->(obj, args, ctx) do
      begin
        contactProvider = ContactProvider.new(
          customer_id: args["data"]["customerId"],
          name: args["data"]["name"],
          enhance_with_linkedin: args["data"]["enhanceWithLinkedin"],
          randomise_contacts: args["data"]["randomiseContacts"],
        )
        contactProvider.save!
        selected_sender_ids = args["selectedSenderIds"]
        contactProvider.assign_senders(selected_sender_ids)
        deliveries = Warehouse::Delivery.find(args["deliveryIds"])
        deliveries.each do |d|
          d.contact_provider_id = contactProvider.id
          d.save!
        end
        return contactProvider
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :updateContactProvider do
    graphoid_model = Graphoid.get(ContactProvider)
    argument :id, !types.ID
    argument :data, graphoid_model.mutation
    argument :deliveryIds, types[types.ID]
    argument :selectedSenderIds, types[types.ID]
    type graphoid_model.type
    resolve ->(obj, args, ctx) do
      begin
        contactProvider = ContactProvider.find(args["id"])
        contactProvider.update_attributes(name: args["data"]["name"], enhance_with_linkedin: args["data"]["enhanceWithLinkedin"], randomise_contacts: args["data"]["randomiseContacts"])
        selected_sender_ids = args["selectedSenderIds"]
        contactProvider.assign_senders(selected_sender_ids)
        deliveries = Warehouse::Delivery.find(args["deliveryIds"])
        deliveries.each do |d|
          d.contact_provider_id = contactProvider.id
          d.save!
        end
        return contactProvider
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :unsuspendSender do
    argument :userId, types.ID
    type types.Boolean
    resolve ->(obj, args, ctx) do
      begin
        return [] if args['userId'].empty?

        user = User.find(args['userId'])
        user.unsuspend! if user.suspended?
        true
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :deleteAccountAssignments do
    argument :senderId, types.ID
    type types.Boolean
    resolve ->(obj, args, ctx) do
      begin
        return [] if args['senderId'].empty?

        AccountAssignment.where(sender_id: args['senderId'], deleted_at: nil).update_all(deleted_at: DateTime.now)
        true
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :removeIdentity do
    argument :identityId, types.ID
    type types.Boolean
    resolve ->(obj, args, ctx) do
      begin
        identity = Identity.find(args['identityId'])
        identity.destroy
        true
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :activateIntegration do
    argument :customerId, types.ID
    argument :provider, types.String
    argument :senderId, types.ID
    type types.ID
    resolve ->(obj, args, ctx) do
      begin
        customer = Company.find(args["customerId"])
        if args["provider"] == "connectleader"
          plugin = customer.get_or_create_plugin(:connectleader)
          integration = V3::Customer::Integrations::Connectleader.create_from_plugin(plugin)
          integration.id
        elsif args["provider"] == "salesforce"
          plugin = customer.get_or_create_plugin(:salesforce)
          integration = V3::Customer::Integrations::Salesforce.create_from_plugin(plugin)
          integration.id
        end
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :createAccountSelector do
    argument :customerId, types.ID
    argument :selectorType, types.String
    argument :name, types.String
    argument :requiredIndustryDataPoints, types[types.String]
    argument :optionalIndustryDataPoints, types[types.String]

    type types.ID
    resolve ->(obj, args, ctx) do
      begin
        customer = Company.find(args["customerId"])
        if args["selectorType"] == "Icp"
          account_selector = V3::Customer::AccountSelectors::IcpAccountSelector.create!(customer_id: customer._id, name: args["name"])
          args["requiredIndustryDataPoints"].each do |i|
            account_selector.required_data_points.create!({ value: i, normalized_value: V3::Data::DataPoints::Industry.normalize_value(i), data_source: V3::Data::DataSource::OUTBOUNDWORKS }, V3::Data::DataPoints::Industry)
          end
          args["optionalIndustryDataPoints"].each do |i|
            account_selector.optional_data_points.create!({ value: i, normalized_value: V3::Data::DataPoints::Industry.normalize_value(i), data_source: V3::Data::DataSource::OUTBOUNDWORKS }, V3::Data::DataPoints::Industry)
          end if args["optionalIndustryDataPoints"]
          account_selector._id
        end
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :updateAccountSelector do
    argument :id, types.ID
    argument :selectorType, types.String
    argument :name, types.String
    argument :requiredIndustryDataPoints, types[types.String]
    argument :optionalIndustryDataPoints, types[types.String]

    type types.ID
    resolve ->(obj, args, ctx) do
      begin
        account_selector = V3::Customer::AccountSelector.find(args["id"])
        if args["selectorType"] == "Icp"
          account_selector.update_attributes!(name: args["name"])
          account_selector.required_data_points.delete_all
          account_selector.optional_data_points.delete_all
          args["requiredIndustryDataPoints"].each do |i|
            account_selector.required_data_points.create!({ value: i, normalized_value: V3::Data::DataPoints::Industry.normalize_value(i), data_source: V3::Data::DataSource::OUTBOUNDWORKS }, V3::Data::DataPoints::Industry)
          end
          args["optionalIndustryDataPoints"].each do |i|
            account_selector.optional_data_points.create!({ value: i, normalized_value: V3::Data::DataPoints::Industry.normalize_value(i), data_source: V3::Data::DataSource::OUTBOUNDWORKS }, V3::Data::DataPoints::Industry)
          end if args["optionalIndustryDataPoints"]
          account_selector._id
        end
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :createContactSelector do
    argument :customerId, types.ID
    argument :selectorType, types.String
    argument :name, types.String
    argument :requiredTitleDataPoints, types[types.String]
    argument :optionalTitleDataPoints, types[types.String]

    type types.ID
    resolve ->(obj, args, ctx) do
      begin
        customer = Company.find(args["customerId"])
        if args["selectorType"] == "Icp"
          contact_selector = V3::Customer::ContactSelectors::IcpContactSelector.create!(customer_id: customer._id, name: args["name"])
          args["requiredTitleDataPoints"].each do |i|
            contact_selector.required_data_points.create!({ value: i, normalized_value: V3::Data::DataPoints::Title.normalize_value(i), data_source: V3::Data::DataSource::OUTBOUNDWORKS }, V3::Data::DataPoints::Title)
          end
          args["optionalTitleDataPoints"].each do |i|
            contact_selector.optional_data_points.create!({ value: i, normalized_value: V3::Data::DataPoints::Title.normalize_value(i), data_source: V3::Data::DataSource::OUTBOUNDWORKS }, V3::Data::DataPoints::Title)
          end
          contact_selector._id
        end
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :updateContactSelector do
    argument :id, types.ID
    argument :selectorType, types.String
    argument :name, types.String
    argument :requiredTitleDataPoints, types[types.String]
    argument :optionalTitleDataPoints, types[types.String]

    type types.ID
    resolve ->(obj, args, ctx) do
      begin
        contact_selector = V3::Customer::ContactSelector.find(args["id"])
        if args["selectorType"] == "Icp"
          contact_selector = V3::Customer::ContactSelectors::IcpContactSelector.update_attributes!(name: args["name"])
          contact_selector.required_data_points.delete_all
          contact_selector.optional_data_points.delete_all
          args["requiredTitleDataPoints"].each do |i|
            contact_selector.required_data_points.create!({ value: i, normalized_value: V3::Data::DataPoints::Title.normalize_value(i), data_source: V3::Data::DataSource::OUTBOUNDWORKS }, V3::Data::DataPoints::Title)
          end
          args["optionalTitleDataPoints"].each do |i|
            contact_selector.optional_data_points.create!({ value: i, normalized_value: V3::Data::DataPoints::Title.normalize_value(i), data_source: V3::Data::DataSource::OUTBOUNDWORKS }, V3::Data::DataPoints::Title)
          end
          contact_selector._id
        end
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :createCustomer do
    graphoid_model = Graphoid.get(Company)
    argument :name, types.String
    argument :domain, types.String

    type graphoid_model.type
    resolve ->(obj, args, ctx) do
      begin
        current_user = ctx[:current_user]
        raise "Unauthorized" if current_user.roles_mask != 1

        domain = ObwDomain.domain(args["domain"])
        company = Company.where(domain: domain).first

        @company = company || Company.find_or_initialize_by(name: args["name"], domain: domain)
        @company.website_url ||= "https://#{domain}"
        @company.isCustomer = true
        @company.v3_enabled = true
        @company.settings = {
          credits_included: 2000,
          feature_plugins: true,
          feature_intro_campaign: true,
          social_proximity: false,
          number_of_seats: 10,
          unlimited_users: false,
          export_campaigns_as: true,
          feature_crm_integration: false,
          advanced_templates: true,
          onboarding_done: false,
          requires_billing: false,
          billing_setup_done: false
        }

        @company.credits_remaining = 12000
        @company.save!
        return @company
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :createSender do
    graphoid_model = Graphoid.get(::User)
    argument :customerId, types.String
    argument :firstName, types.String
    argument :lastName, types.String
    argument :email, types.String

    type graphoid_model.type
    resolve ->(obj, args, ctx) do
      begin
        customer = Company.find(args["customerId"])
        current_user = ctx[:current_user]
        auth = false
        if (customer._id == current_user.company_id)
          auth = true if current_user.roles_mask < 4 # only managers
        end
        auth = true if current_user.roles_mask == 1 # allow super admins
        raise "Unauthorized" unless auth

        current_employees_count = customer.users.where(:roles_mask.lte => 4).count
        if customer.check_setting_value(:number_of_seats, :greater_than, current_employees_count) || customer.check_setting(:unlimited_users)
          # see if the new user already exists in the db.
          @user = User.where(email: args[:email]).first
          if (@user.blank?)
            @user = User.new(email: args[:email], first_name: args[:firstName], last_name: args[:lastName])
            @user.company = customer
            # @user.password = Devise.friendly_token[0,20]
            # @user.password_confirmation = @user.password
          end
          if @user.company == customer
            @user.roles = ["employee"]
            @user.user_type = UserTypes::SENDER
            @user.plugin_token = Devise.friendly_token[0, 20]
            @user.daily_sending_limit = 0
            @user.unset(:confirmed_at)
            @user.set_new_confirmation_token
            if @user.save!
              V3Mailer.confirmation_instructions(@user, @user.confirmation_token).deliver unless @user.new_record?
              return @user
            else
              raise
            end
          else
            raise
          end
        else
          raise
        end
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :reSendUserConfirmationEmail do
    graphoid_model = Graphoid.get(::User)
    argument :id, types.String

    type graphoid_model.type
    resolve ->(obj, args, ctx) do
      begin
        current_user = ctx[:current_user]
        @user = User.find(args["id"])
        raise "User Not Found" unless @user

        if @user.company_id == current_user.company_id || current_user.roles_mask == 1 # admin
          if @user.roles_mask <= 4 && @user.sign_in_count == 0
            @user.unset(:confirmed_at)
            @user.set_new_confirmation_token
            @user.save
            V3Mailer.confirmation_instructions(@user, @user.confirmation_token).deliver_now
          end
        end
        return @user
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :startAccountCreation do
    argument :customerId, types.String

    type types.Boolean
    resolve ->(obj, args, ctx) do
      begin
        current_user = ctx[:current_user]

        raise "Not Authorised" unless current_user.roles_mask == 1

        # check if there already is a job running
        return false if Job.where(customerId: args["customerId"], class_name: "V3::Workers::CustomerAccountCreator", status: Job::Status::RUNNING).any?
        limit = 100
        JobDispatchService.perform_async("V3::Workers::CustomerAccountCreator", args["customerId"], limit)

        return true
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :startContactCreation do
    argument :customerId, types.String

    type types.Boolean
    resolve ->(obj, args, ctx) do
      begin
        current_user = ctx[:current_user]

        raise "Not Authorised" unless current_user.roles_mask == 1

        # check if there already is a job running
        return false if Job.where(customerId: args["customerId"], class_name: "V3::Workers::CustomerContactCreator", status: Job::Status::RUNNING).any?
        limit = 100
        JobDispatchService.perform_async("V3::Workers::CustomerContactCreator", args["customerId"], limit)

        return true
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :startContactResearchRunner do
    argument :customerId, types.String

    type types.Boolean
    resolve ->(obj, args, ctx) do
      begin
        current_user = ctx[:current_user]

        raise "Not Authorised" unless current_user.roles_mask == 1

        # check if there already is a job running
        return false if Job.where(customerId: args["customerId"], class_name: "V3::Workers::ContactResearchRunner", status: Job::Status::RUNNING).any?

        JobDispatchService.perform_async("V3::Workers::ContactResearchRunner", args["customerId"])

        return true
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :startContactResearchersCreation do
    argument :customerId, types.String

    type types.Boolean
    resolve ->(obj, args, ctx) do
      begin
        current_user = ctx[:current_user]

        raise "Not Authorised" unless current_user.roles_mask == 1

        # check if there already is a job running
        return false if Job.where(customerId: args["customerId"], class_name: "V3::Workers::CustomerStoryPreResearchAnalyzer", status: Job::Status::RUNNING).any?

        JobDispatchService.perform_async("V3::Workers::CustomerStoryPreResearchAnalyzer", args["customerId"])

        return true
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :startStoryRunner do
    argument :customerId, types.String

    type types.Boolean
    resolve ->(obj, args, ctx) do
      begin
        current_user = ctx[:current_user]

        raise "Not Authorised" unless current_user.roles_mask == 1

        # check if there already is a job running
        return false if Job.where(customerId: args["customerId"], class_name: "V3::Workers::CustomerStoryPostResearchAnalyzer", status: Job::Status::RUNNING).any?

        JobDispatchService.perform_async("V3::Workers::CustomerStoryPostResearchAnalyzer", args["customerId"])

        return true
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :salesforceIntegrationSetup do
    argument :customerId, types.String

    type types.Boolean
    resolve ->(obj, args, ctx) do
      begin
        current_user = ctx[:current_user]

        raise "Not Authorized" unless current_user.roles_mask == 2

        integration = V3::Customer::Integrations::Salesforce.where(customer_id: args["customerId"]).first
        integration.setup() # intentionally blocking call.

        return true
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :pauseStoryContact do
    graphoid_model = Graphoid.get(V3::Customer::StoryContact)
    argument :id, types.String

    type graphoid_model.type
    resolve ->(obj, args, ctx) do
      begin
        story_contact = V3::Customer::StoryContact.find(args["id"])
        current_user = ctx[:current_user]
        if current_user._id == story_contact.sender_id
          if (story_contact.status == V3::Status::StatusValue::NEW)
            story_contact.replace_status(V3::Status::StatusValue::NEW, V3::Status::StatusValue::PAUSED)
            story_contact.contact.add_status(V3::Status::StatusValue::PAUSED)
            story_contact.contact.save!
            options = { contact_id: story_contact.contact._id, account_id: story_contact.account_id, sender_id: story_contact.sender_id }
            story_contact.story.log(V3::Customer::StoryJournal::EventTypes::STORYCONTACTPAUSED, options)
          end
        else
          raise "Not Authorized"
        end
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :refreshStoryContact do
    graphoid_model = Graphoid.get(V3::Customer::StoryContact)
    argument :id, types.String

    type graphoid_model.type
    resolve ->(obj, args, ctx) do
      begin
        # return GraphQL::ExecutionError.new("insuficient permission") unless Graphoid::Auth.check(ctx, mongo_model, :update)
        story_contact = V3::Customer::StoryContact.find(args["id"])
        story = story_contact.story
        story.refresh_story_contact(story_contact)
      rescue => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end
end
