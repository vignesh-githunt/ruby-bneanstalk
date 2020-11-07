Types::CustomerProspectingDataType = GraphQL::ObjectType.define do
  name 'CustomerProspectingData'

  # it has the following fields
  field :id, !types.ID
  field :data, Graphoid::Scalars::Hash
end
