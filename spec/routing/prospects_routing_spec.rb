require "rails_helper"

RSpec.describe "Api::V3::ProspectsController", type: :routing do
  describe "routing" do

    it "routes to #index" do
      expect(get: "api/v3/prospects").to route_to("api/v3/prospects#index", format: :json)
    end

    it "routes to #show" do
      expect(get: "api/v3/prospects/1").to route_to("api/v3/prospects#show", id: "1", format: :json)
    end

    it "routes to #create" do
      expect(post: "api/v3/prospects").to route_to("api/v3/prospects#create", format: :json)
    end

    it "routes to #update via PUT" do
      expect(put: "api/v3/prospects/1").to route_to("api/v3/prospects#update", id: "1", format: :json)
    end

    it "routes to #update via PATCH" do
      expect(patch: "api/v3/prospects/1").to route_to("api/v3/prospects#update", id: "1", format: :json)
    end

    it "routes to #destroy" do
      expect(delete: "api/v3/prospects/1").to route_to("api/v3/prospects#destroy", id: "1", format: :json)
    end

  end
end
