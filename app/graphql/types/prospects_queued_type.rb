Types::ProspectsQueuedType = GraphQL::ObjectType.define do
  name 'ProspectsQueued'

  # it has the following fields
  field :id, !types.ID
  field :data, types[Graphoid::Scalars::Hash]
end
