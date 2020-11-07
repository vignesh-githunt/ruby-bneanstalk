Types::LoginUserType = GraphQL::ObjectType.define do
  name 'LoginUser'

  # it has the following fields
  field :id, !types.ID
  field :token, types.String
  field :user, Types::Hash
end

Types::Hash = GraphQL::ScalarType.define do
  name "Hash"
  description "List of key-value pairs. Also they can store any kind of JSON object."
end
