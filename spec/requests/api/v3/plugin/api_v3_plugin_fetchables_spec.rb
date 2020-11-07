require 'rails_helper'

RSpec.describe Api::V3::Plugin::FetchablesController, type: :request do
  describe "GET /api/v3/plugin/fetchables" do
    it "works! (now write some real specs)" do
      get api_v3_plugin_fetchables_path

      # this returns unauthorized (401), we need to setup a logged user
      expect(response).to have_http_status(401)
    end
  end
end
