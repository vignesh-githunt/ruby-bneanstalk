Types::DeviseType = GraphQL::ObjectType.define do
  name "Devise"
  field :login do
    type Types::LoginUserType
    description "Login for users"
    argument :email, types.String
    argument :password, types.String
    resolve ->(obj, args, ctx) do
      user = User.find_for_authentication(email: args.email)
      return nil if !user
      is_valid_for_auth = user.valid_for_authentication? {
        user.valid_password?(args.password)
      }

      return nil if !is_valid_for_auth
      user.set_jit_token if user.jti.blank?
      token = user.generate_jwt
      data = {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: user.email,
        title: user.title,
        rolesMask: user.roles_mask,
        roles: user.roles,
        workflowRoles: user.workflow_roles,
        companyId: user.company_id,
        company: {
          id: user.company_id,
          name: user.company.name
        },
        onlineTime: user.online_time,
        imageUrl: user.image_url
      }

      result = OpenStruct.new(token: token, user: data)
      return result
    end
  end

  field :xdrLogin do
    type Types::LoginUserType
    description "Login for users"
    argument :email, types.String
    argument :password, types.String
    resolve ->(obj, args, ctx) do
      user = User.find_for_authentication(email: args.email)
      return nil if !user
      is_valid_for_auth = user.valid_for_authentication? {
        user.valid_password?(args.password)
      }

      return nil if !is_valid_for_auth
      user.set_jit_token if user.jti.blank?
      token = user.generate_jwt
      data = {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: user.email,
        title: user.title,
        rolesMask: user.roles_mask,
        roles: user.roles,
        workflowRoles: user.workflow_roles,
        pluginToken: user.pluginToken,
        pusherChannel: user.pusher_channel,
        companyId: user.company_id,
        company: {
          id: user.company_id,
          name: user.company.name
        },
        onlineTime: user.online_time,
        imageUrl: user.image_url
      }

      result = OpenStruct.new(token: token, user: data)
      return result
    end
  end

  field :reset_password do
    type types.Boolean
    description "Set the new Password"
    argument :password, types.String
    argument :password_confirmation, types.String
    argument :reset_password_token, types.String
    resolve ->(obj, args, ctx) do
      user = User.with_reset_password_token(args.reset_password_token)
      return false if !user
      user.reset_password(args.password, args.password_confirmation)
      true
    end
  end

  field :account_confirmation do
    type Types::LoginUserType
    description "Account Activation"
    argument :password, types.String
    argument :password_confirmation, types.String
    argument :confirmation_token, types.String
    resolve ->(obj, args, ctx) do
      user = User.confirm_by_token(args.confirmation_token)
      return nil if !user
      user.update_attributes(password: args.password,
                             password_confirmation: args.password_confirmation)

      is_valid_for_auth = user.valid_for_authentication? {
        user.valid_password?(args.password)
      }
      return nil if !is_valid_for_auth
      token = user.generate_jwt
      data = {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: user.email,
        title: user.title,
        rolesMask: user.roles_mask,
        roles: user.roles,
        workflowRoles: user.workflow_roles,
        companyId: user.company_id,
        company: {
          id: user.company_id,
          name: user.company.name
        },
        onlineTime: user.online_time,
        imageUrl: user.image_url
      }
      result = OpenStruct.new(token: token, user: data)
      return result
    end
  end

  field :update_user do
    type Types::LoginUserType
    description "Update user"
    argument :password, types.String
    argument :password_confirmation, types.String
    resolve ->(obj, args, ctx) do
      user = ctx[:current_user]
      return nil if !user
      user.update!(
        password: args.password,
        password_confirmation: args.password_confirmation
      )
      user
    end
  end

  field :reset_password_instructions do
    type types.Boolean
    description "Send password reset instructions to users email"
    argument :email, types.String
    resolve ->(obj, args, ctx) do
      user = User.find_by(email: args.email)
      return false if !user
      user.send_reset_password_instructions
      true
    end
  end

  field :token_login do
    type Types::LoginUserType
    description "JWT token login"
    resolve ->(obj, args, ctx) do
      ctx[:current_user]
    end
  end

  field :logout do
    type types.Boolean
    description "Logout for users"
    resolve ->(obj, args, ctx) do
      if ctx[:current_user]
        ctx[:current_user].update(jti: SecureRandom.uuid)
        return true
      end
      false
    end
  end
end
