Types::JournalAggregationType = GraphQL::ObjectType.define do
  name 'JournalAggregation'

  # it has the following fields
  field :id, !types.ID
  field :event, types.String
  field :startDate, Graphoid::Scalars::DateTime
  field :endDate, Graphoid::Scalars::DateTime
  field :data, types[Graphoid::Scalars::Hash]
  field :totalCount, types.Int
  field :totalAccountCount, types.Int
end
