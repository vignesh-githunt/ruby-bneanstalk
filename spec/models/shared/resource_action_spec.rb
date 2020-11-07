require "rails_helper"

RSpec.describe ResourceAction, type: :model do

  describe "after update" do

    before do
      @company = Company.create!(name: "company_name")
      @user = User.create!(email: "#{SecureRandom.hex}@hash.com", first_name: 'm', last_name: 'm', company: @company, roles_mask: 4)
      @product_wizard = @company.product_wizards.create!

      @section = Section.create!(name: 'section_name')
      @resource_definition = ResourceDefinition.create!(name: 'resource_definition_name', section: @section)
      @resource = Resource.create!(product_wizard: @product_wizard, resource_definition: @resource_definition)

      @resource_action = ResourceAction.create!(
        resource: @resource,
        updated_by: @user
      )

      @resource_action.create_action(name: 'action_name')
    end

    describe "after update done field" do
      context "when set to true" do
        before do
          @resource_action.update!(done: true)
        end

        it do
          log = Log.last
          expect(log.message).to eq("added label action_name to resource_definition_name in section section_name")
          expect(log.user).to eq(@user)
          expect(log.product_wizard).to eq(@product_wizard)
          expect(log.resource).to eq(@resource)

          ra = @resource_action
          expect(ra.completed_by).to be
          expect(ra.completed_by).to eq(ra.updated_by)
          expect(ra.completed_at).to be
          expect(ra.completed_at.iso8601).to eq(ra.updated_at.iso8601)
        end
      end

      context "when set to false" do
        before do
          @resource_action.update!(done: true)
          @resource_action.update!(done: false)
        end

        it do
          log = Log.last
          expect(log.message).to eq("removed label action_name from resource_definition_name in section section_name")
          expect(log.user).to eq(@user)

          ra = @resource_action
          expect(ra.completed_at).to be_nil
          expect(ra.completed_by).to be_nil
        end
      end
    end

    after do
      @company.users = []
      [@user, @product_wizard, @action, @section, @resource_definition, @resource, @resource_action, @company].each do |model|
        model.destroy if model
      end
    end
  end
end
