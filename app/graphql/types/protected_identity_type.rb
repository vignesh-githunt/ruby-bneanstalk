Types::ProtectedIdentityType = GraphQL::ObjectType.define do
  name 'ProtectedIdentity'

  # it has the following fields
  field :id, !types.ID
  field :createdAt, Graphoid::Scalars::DateTime
  field :updatedAt, Graphoid::Scalars::DateTime
  field :nickname, types.String
  field :email, types.String
end
