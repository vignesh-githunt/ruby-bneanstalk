class MyFailureApp < Devise::FailureApp
  def respond
    if request.format == :json
      json_failure
    else
      super
    end
  end

  def redirect_url
    "/graphql_unauthorized"
  end

  def json_failure
    self.status = 401
    self.content_type = 'application/json'
    self.response_body = '{"error" : "authentication error"}'
  end
end
