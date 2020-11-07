require 'rails_helper'

RSpec.describe User, type: :model do
  describe "extension status" do
    before do
      @extension_user = User.create!(first_name: "bob", last_name: "tester", email: "bob@example.com", plugin_token: 'ABC', roles_mask: 1, company: Company.create!(name: "foo corp") )
    end

    before :each do
      ExtensionStatusEvent.destroy_all
    end

    it "should add a new status fields always" do
      @extension_user.record_extension_status websocket: true, linkedin: true, sales_navigator: true, platform: true, version: "1.1"
      @extension_user.record_extension_status websocket: true
      expect(@extension_user.extension_status_events.count).to eq(2)
    end
  end

  describe "suspensions" do
    before do
      @user = User.create!(first_name: "bob", last_name: "tester", email: "bob@example.com", roles_mask: 1, company: Company.create!(name: "foo corp") )
    end
    describe "calling suspend!" do
      before do
        travel_to(@suspended_at = DateTime.current) do
          @suspension = @user.suspend!
        end
      end

      it "should add a suspension" do
        expect(@user.suspensions.count).to eq(1)
      end

      it "should log the suspension" do
        expect(JSON.parse(EventLog.first.data[:suspension_id])).to eq(@suspension.id.to_s)
      end

      it "should add an active suspension" do
        expect(@user.active_suspension.id).to eq(@suspension.id)
      end

      it "should not create a new suspension when calling suspend! again" do
        @new_suspension = @user.suspend!
        expect(@new_suspension).to eq(@suspension)
      end

      it "should return true when calling suspend?" do
        expect(@user.suspended?).to be_truthy
      end

      it "should record the time of the suspension" do
        expect(@user.active_suspension.suspended_at.to_i).to eq(@suspended_at.to_i)
      end

      describe "and then calling unsuspend!" do
        before do
          travel_to(@unsuspended_at = DateTime.now) do
            @user.unsuspend!
          end
        end

        it "should not have an active suspension" do
          expect(@user.active_suspension).to be_nil
        end

        it "should not change suspensions count" do
          expect(@user.suspensions.count).to eq(1)
        end

        it "should return false when calling suspended?" do
          expect(@user.suspended?).to be_falsy
        end

        it "should record the time of the reinstatement" do
          expect(@user.suspensions.first.unsuspended_at.to_i).to eq(@unsuspended_at.to_i)
        end
      end
    end
  end
end
