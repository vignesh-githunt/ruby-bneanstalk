require "rails_helper"

RSpec.describe PlayExecution, type: :model do

  describe "after create" do

    before do
      @company = Company.create!(name: "company_name")
      @user = User.create!(email: "#{SecureRandom.hex}@hash.com", first_name: 'm', last_name: 'm', company: @company, roles_mask: 4)
      @product_wizard = @company.product_wizards.create!(product_name: "product_wizard_name")
      @play_definition = PlayDefinition.create!(name: 'play_definition_name')

      @play_execution = PlayExecution.create!(
        play_definition: @play_definition,
        product_wizard: @product_wizard,
        user: @user
      )
    end

    it do
      log = Log.last
      expect(log.message).to eq(" called the play play_definition_name in product_wizard_name")
      expect(log.user).to eq(@user)
      expect(log.product_wizard).to eq(@product_wizard)
    end

    after do
      @company.users = []
      [@user, @product_wizard, @play_definition, @play_execution, @company].each do |model|
        model.destroy if model
      end
    end
  end
end
