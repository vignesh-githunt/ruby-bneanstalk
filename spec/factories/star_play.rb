FactoryBot.define do
  factory :play_definition do
    id "5ae384150218238c115b58c8"
    name "Pause Campaign"
    play_type "LiveRed"
    description "Pause the campaign! This action only affects email messages going out. If there are other actions mid-flight on the messaging, data, or ops teams - you must reach out to those leads individually and pause those campaigns."
    repeatable true
    order 20
  end
  factory :rad1, class: 'ResourceActionDefinition' do
    id "5ae383d80218238c115b4432"
    description "This is the notification that we should pause this campaign."
    workflow_role "SalesDevelopmentExecutive"
    estimated_days 0
    total_estimated_days 2
    order 0
    dependent_ids nil
  end
  factory :rad2, class: 'ResourceActionDefinition' do
    id "5ae384150218238c115b58cf"
    description "This is when the Data Operator confirms that the campaign is in fact paused."
    workflow_role "DataOperator"
    estimated_days 0
    total_estimated_days 2
    order 0
    dependent_ids nil
  end
  factory :resource_definition do
    id "5ae383d3970d6a5c5edc8c08"
    customer_can_edit false
    customer_can_view false
    format "%s"
    formula nil
    key_metric false
    name "Campaign Pause Conditions"
    order 0
    description "This is the reason for pausing a campaign and the conditions under which it will be restarted."
    deleted false
  end
  factory :company do
    name "AbcCompany"
  end
  factory :user do
    email "jim@AbcCompany.com"
    company
    first_name "Jane"
    last_name "Doe"
  end
  factory :product_wizard do
    product_name "best sequences"
  end
  factory :ad1, class: 'ActionDefinition' do
    id "5ae383d0970d6a5c5edc8a46"
    name "Proposed"
    color "green"
  end
  factory :section do
    id "5ae383d0970d6a5c5edc8a2e"
    name "Reporting"
    hidden true
    order 4
    primary false
  end
end