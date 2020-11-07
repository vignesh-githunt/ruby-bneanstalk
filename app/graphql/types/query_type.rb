Types::QueryType = GraphQL::ObjectType.define do
  name "Query"

  Graphoid::Models.all.each do |model|
    Graphoid::Queries::One.new(model, self)
    Graphoid::Queries::Many.new(model, self)
  end

  field :me do
    graphoid_model = Graphoid.get(User)
    type graphoid_model.type
    description "JWT token login"
    resolve ->(obj, args, ctx) do
      ctx[:current_user]
    end
  end

  field :contactDataAggregation do
    argument :customerId, types.ID
    argument :dataPoint, types.String
    argument :senderId, types.ID

    type Types::DataPointAggregationType

    resolve ->(obj, args, ctx) do
      begin
        customer = Company.find(args['customerId'])
        sender = User.find(args['senderId']) if args['senderId']
        data_point_field = V3::Customer::Contact.data_point_class_to_field_name("V3::Data::DataPoints::#{args['dataPoint']}")&.name || args['dataPoint']
        result = V3::Customer::Contact.group_by_data_point(customer._id, data_point_field, sender&._id).first
        if result.blank?
          return OpenStruct.new(
            id: "#{args['customerId']}-#{args['dataPoint']}-#{args['senderId']}",
            dataPoint: args['dataPoint'],
            data: [],
            isTop20Percent: false,
            totalCount: 0
          )
        end

        totalCount = result["total_count"]
        top_20_percent = (result["result"].size * 0.2).round + 1
        is_top_20_percent = result["result"].size > 100 ? true : false
        data = result["result"].size > 100 ? result["result"].first(top_20_percent) : result["result"]
        OpenStruct.new(
          id: "#{args['customerId']}-#{args['dataPoint']}-#{args['senderId']}",
          dataPoint: args['dataPoint'],
          data: data,
          isTop20Percent: is_top_20_percent,
          totalCount: totalCount
        )
      rescue Exception => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :storyJournalAggregation do
    argument :customerId, types.ID
    argument :event, types.String
    argument :format, types.String
    argument :startDate, Graphoid::Scalars::DateTime
    argument :endDate, Graphoid::Scalars::DateTime
    argument :storyId, types.ID
    argument :groupByStoryId, types.Boolean
    argument :senderId, types.ID
    argument :groupBySender, types.Boolean
    argument :accountId, types.ID
    argument :groupByAccount, types.Boolean

    type Types::JournalAggregationType

    resolve ->(obj, args, ctx) do
      begin
        data = V3::Customer::StoryJournal.group_by_event(args['customerId'], args['event'], args['format'], args['startDate'], args['endDate'], args['storyId'], args['groupByStoryId'], args['senderId'], args['groupBySender'], args['groupByAccount'], args['accountId']).to_a
        totalUniqueContacts = V3::Customer::StoryJournal.where(customer_id: args['customerId'], event: args['event'], event_date: { "$gt": args['startDate'], "$lte": args['endDate'] })
        if (args['groupByStoryId'])
          totalUniqueContacts = totalUniqueContacts.where(story_id: args['storyId'])
        end
        if (args['groupBySender'])
          totalUniqueContacts = totalUniqueContacts.where(sender_id: args['senderId'])
        end
        if (args['accountId'].present?)
          totalUniqueContacts = totalUniqueContacts.where(account_id: args['accountId'])
        end

        OpenStruct.new(
          id: "#{args['event']}-#{args['startDate'].to_s}#{args['endDate'].to_s}-#{args['format']}-#{args['storyId']}-#{args['senderId']}-#{args['groupBySender']}--#{args['groupByAccount']}",
          event: args['event'],
          startDate: args['startDate'],
          endDate: args['endDate'],
          data: data,
          totalCount: totalUniqueContacts.distinct("contact_id").count,
          totalAccountCount: totalUniqueContacts.distinct("account_id").count
        )
      rescue Exception => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :accountJournalAggregation do
    argument :customerId, types.ID
    argument :event, types.String
    argument :format, types.String
    argument :startDate, Graphoid::Scalars::DateTime
    argument :endDate, Graphoid::Scalars::DateTime
    argument :accountId, types.ID
    argument :groupByAccountId, types.Boolean

    type Types::JournalAggregationType

    resolve ->(obj, args, ctx) do
      begin
        data = V3::Customer::AccountJournal.group_by_event(args['customerId'], args['event'], args['format'], args['startDate'], args['endDate'], args['accountId'], args['groupByAccountId']).to_a
        totalUnique = V3::Customer::AccountJournal.where(customer_id: args['customerId'], event: args['event'], event_date: { "$gt": args['startDate'], "$lte": args['endDate'] })
        OpenStruct.new(
          id: "#{args['event']}-#{args['startDate'].to_s}#{args['endDate'].to_s}-#{args['format']}-#{args['accountId']}",
          event: args['event'],
          startDate: args['startDate'],
          endDate: args['endDate'],
          data: data,
          totalCount: args['event'].include?("contact") ? totalUnique.distinct("contact_id").count : totalUnique.distinct("account_id").count
        )
      rescue Exception => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :loggedInUser do
    type Graphoid.get(User).type
    resolve ->(obj, args, ctx) do
      ctx[:current_user]
    end
  end

  field :checkDoNotContact do
    type Graphoid.get(DoNotContactAccount).type

    argument :customerId, types.ID
    argument :email, types.String

    resolve ->(obj, args, ctx) do
      service = DoNotContactCheckService.new(args["customerId"])
      begin
        service.check_with_details(args["email"])
      rescue => e
        raise GraphQL::ExecutionError.new(e.message)
      end
    end
  end

  field :getContactsProspected do
    argument :start, Graphoid::Scalars::DateTime
    argument :end, Graphoid::Scalars::DateTime

    type Types::ContactsProspectedType
    resolve ->(obj, args, ctx) do
      begin
        data = FetchableService.get_contacts_prospected(args['start'], args['end']) || []
        OpenStruct.new(id: "#{args['start'].to_s}#{args['end'].to_s}", data: data)
      rescue Exception => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :getCustomerProspectingData do
    argument :customerId, types.ID
    argument :from, Graphoid::Scalars::DateTime
    argument :to, Graphoid::Scalars::DateTime

    type Types::CustomerProspectingDataType
    resolve ->(obj, args, ctx) do
      begin
        data = FetchableService.new.get_customer_prospecting_data(args['customerId'], args['from'], args['to']) || []
        OpenStruct.new(id: "customer-#{args['customerId']}", data: data)
      rescue Exception => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :getProspectsQueued do
    type Types::ProspectsQueuedType
    resolve ->(obj, args, ctx) do
      begin
        data = FetchableService.get_prospects_queued
        OpenStruct.new(id: 'get_prospects_queued', data: data)
      rescue Exception => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :warehouseCohortsReport do
    argument :customerId, types.ID

    type Types::WarehouseCohortsType
    resolve ->(obj, args, ctx) do
      begin
        data = Warehouse.cohorts_data(args['customerId'])
        OpenStruct.new(id: 'warehouse_cohorts_report', data: data)
      rescue Exception => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :eventLogsReport do
    argument :from, Graphoid::Scalars::DateTime
    argument :to, Graphoid::Scalars::DateTime
    argument :levelStart, types.Int
    argument :levelEnd, types.Int

    type Graphoid::Scalars::Array

    resolve ->(obj, args, ctx) do
      EventLog.collection.aggregate([
                                      { "$match" => {
                                        "created_at" => { "$gte" => args['from'], "$lt" => args['to'] },
                                        "level" => { "$gte" => args['levelStart'], "$lt" => args['levelEnd'] },
                                      } },
                                      { "$group" => { "_id" => "$event", "count" => { "$sum" => 1 } } },
                                      { "$sort" => { "count" => -1 } }
                                    ]).to_a
    end
  end

  field :UniqueContactsContacted do
    type Graphoid::Scalars::Array
    resolve ->(obj, arg, ctx) do
      Statistic::Service.net_new_contacts_trailing_weeks
    end
  end

  field :UniqueContactsContactedForCustomer do
    argument :customerId, types.ID

    type Graphoid::Scalars::Array
    resolve ->(obj, args, ctx) do
      Statistic::Service.raw_unique_contacts_per_sender_data_for_company(args['customerId'])
    end
  end

  field :CustomerWeeklyStats do
    argument :customerId, types.ID

    type Graphoid::Scalars::Array
    resolve ->(obj, args, ctx) do
      Statistic::Service.weekly_contacted_stats_per_customer(args['customerId'])
    end
  end

  field :CustomerOpenReplyStats do
    argument :customerId, types.ID

    type Graphoid::Scalars::Array
    resolve ->(obj, args, ctx) do
      Statistic::Service.last_weeks_opened_and_replied_stats_per_customer(args['customerId'])
    end
  end

  field :InstanceUrlQuery do
    argument :customerId, types.ID

    type types.String
    resolve ->(obj, args, ctx) do
      return "https://upsidetravel.my.salesforce.com" if Rails.env.development?

      user_ids = Company.find(args['customerId'])&.users.where(:roles_mask.lte => 4).pluck(:_id)
      Identity.where(:user_id.in => user_ids, provider: "salesforce").first&.instance_url
    end
  end

  field :ContactsContactedPerSender do
    type Graphoid::Scalars::Array
    resolve ->(obj, arg, ctx) do
      Statistic::Service.net_new_contacts_trailing_weeks
    end
  end

  field :ContactsContactedPerSender do
    type Graphoid::Scalars::Array
    resolve ->(obj, arg, ctx) do
      Statistic::Service.net_new_contacts_per_sender_per_week
    end
  end

  field :ContactsContactedPerCustomer do
    type Graphoid::Scalars::Array
    resolve ->(obj, arg, ctx) do
      Statistic::Service.net_new_contacts_per_customer
    end
  end

  field :getSalesloftPluginSequences do
    argument :userId, types.ID
    type Graphoid::Scalars::Array

    resolve ->(obj, arg, ctx) do
      begin
        return [] if arg['userId'].empty?

        user = User.find(arg['userId'])
        company = user.company
        salesloft_plugin = SalesloftPlugin.where(company_id: user.company_id).first
        salesloft_plugin&.sequences(user)
      rescue Exception => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :getConnectleaderPluginSequences do
    argument :userId, types.ID
    type Graphoid::Scalars::Array

    resolve ->(obj, arg, ctx) do
      begin
        return [] if arg['userId'].empty?

        user = User.find(arg['userId'])
        company = user.company
        connectleader_plugin = ConnectleaderPlugin.where(company_id: user.company_id).first
        connectleader_plugin&.sequences(user)
      rescue Exception => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :getOutreachPluginSequences do
    argument :userId, types.ID
    type Graphoid::Scalars::Array

    resolve ->(obj, arg, ctx) do
      begin
        return [] if arg['userId'].empty?

        user = User.find(arg['userId'])
        outreach_plugin = OutreachPlugin.where(company_id: user.company_id).first
        outreach_plugin&.sequences(user)
      rescue Exception => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :getMixmaxPluginSequences do
    argument :userId, types.ID
    type Graphoid::Scalars::Array

    resolve ->(obj, arg, ctx) do
      begin
        return [] if arg['userId'].empty?

        user = User.find(arg['userId'])
        plugin = MixmaxPlugin.where(company_id: user.company_id).first
        plugin&.sequences(user)
      rescue Exception => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end

  field :getSalesforceFields do
    argument :integrationId, !types.ID
    argument :sobjectName, !types.String
    type Graphoid::Scalars::Array

    resolve ->(obj, args, ctx) do
      begin
        return [] if args['integrationId'].empty?

        integration = V3::Customer::Integration.find(args['integrationId'])

        result = integration.default_client.describe(args['sobjectName'])
        return result.fields.select { |x| x["custom"] == true }
      rescue Exception => e
        GraphQL::ExecutionError.new(e)
      end
    end
  end
end
