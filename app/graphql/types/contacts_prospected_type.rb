Types::ContactsProspectedType = GraphQL::ObjectType.define do
  name 'ContactsProspected'

  # it has the following fields
  field :id, !types.ID
  field :data, types[Graphoid::Scalars::Hash]
end
