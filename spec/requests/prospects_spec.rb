require 'rails_helper'

RSpec.describe "Prospects", type: :request do
  describe "GET /prospects" do
    it "works! (now write some real specs)" do
      get api_v3_prospects_path

      # this returns unauthorized (401), we need to setup a logged user
      expect(response).to have_http_status(401)
    end
  end
end
