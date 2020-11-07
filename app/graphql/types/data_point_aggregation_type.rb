Types::DataPointAggregationType = GraphQL::ObjectType.define do
  name 'DataPointAggregation'

  # it has the following fields
  field :id, !types.ID
  field :dataPoint, types.String
  field :data, types[Graphoid::Scalars::Hash]
  field :isTop20Percent, types.Boolean
  field :totalCount, types.Int
end
