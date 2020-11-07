require "rails_helper"

RSpec.describe "Api::V3::Plugin::FetchablesController", type: :routing do
  describe "routing" do

    it "routes to #index" do
      expect(get: "api/v3/plugin/minables").to route_to("api/v3/plugin/fetchables#index", format: :json)
    end

    it "routes to #show" do
      expect(get: "api/v3/plugin/minables/1").to route_to("api/v3/plugin/fetchables#show", id: "1", format: :json)
    end

    it "routes to #create" do
      expect(post: "api/v3/plugin/minables").to route_to("api/v3/plugin/fetchables#create", format: :json)
    end

    it "routes to #update via PUT" do
      expect(put: "api/v3/plugin/minables/1").to route_to("api/v3/plugin/fetchables#update", id: "1", format: :json)
    end

    it "routes to #update via PATCH" do
      expect(patch: "api/v3/plugin/minables/1").to route_to("api/v3/plugin/fetchables#update", id: "1", format: :json)
    end

    it "routes to #destroy" do
      expect(delete: "api/v3/plugin/minables/1").to route_to("api/v3/plugin/fetchables#destroy", id: "1", format: :json)
    end

  end
end
