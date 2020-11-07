require "rails_helper"

RSpec.describe Opportunity, type: :model do

  describe "after update" do

    before do
      @company = Company.create!(name: "company1")
      @user = User.create!(email: "#{SecureRandom.hex}@example.com", first_name: 'm', last_name: 'm', company: @company, roles_mask: 4)
      @product_wizard = @company.product_wizards.create!(product_name: "Excellent Product")

      @opportunity = Opportunity.create!(
        company: @company,
        company_name: "company2",
        product_wizard: @product_wizard,
        created_by: @user
      )

      @referral = Referral.create!(
        company: @company,
        company_name: "company3",
        product_wizard: @product_wizard,
        created_by: @user
      )
    end

    describe "checks a log entry for opportunity" do
      it do
        log = Log.where(opportunity_id: @opportunity.id).first
        expect(log.message).to eq(" created a new opportunity for company1's product Excellent Product with company2 ")
        expect(log.user).to eq(@user)
        expect(log.product_wizard).to eq(@product_wizard)
      end
    end

    describe "checks a log entry for referral" do
      it do
        log = Log.where(referral_id: @referral.id).first
        expect(log.message).to eq(" created a new opportunity for company1's product Excellent Product with company3 ")
        expect(log.user).to eq(@user)
        expect(log.product_wizard).to eq(@product_wizard)
      end
    end

    after do
      @company.users = []
      [@user, @product_wizard, @opportunity, @company].each do |model|
        model.destroy if model
      end
    end
  end
end
