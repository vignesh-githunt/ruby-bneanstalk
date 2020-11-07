Types::WarehouseCohortsType = GraphQL::ObjectType.define do
  name 'WarehouseCohorts'

  # it has the following fields
  field :id, !types.ID
  field :data, types[Graphoid::Scalars::Hash]
end
