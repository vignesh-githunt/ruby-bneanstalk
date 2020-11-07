require "rails_helper"

RSpec.describe EventLog, type: :model do
  describe "basic creation" do
    it "should increment the total number of events" do
      count = EventLog.count
      EventLog.add! "simple event"
      expect(EventLog.count).to eq(count + 1)
    end

    it "should fail if message argument missing" do
      expect do
        EventLog.add!
      end.to raise_error(ArgumentError)
    end

    it "should fail if message string is empty" do
      expect do
        EventLog.add! ""
      end.to raise_error(Mongoid::Errors::Validations)
    end

    it "should create an event with success log level" do
      log = EventLog.success "success event"
      expect(log.level).to eq(EventLog::LEVELS[:success])
    end

    it "should create an event with info log level" do
      log = EventLog.info "info event"
      expect(log.level).to eq(EventLog::LEVELS[:info])
    end

    it "should create an event with warn log level" do
      log = EventLog.warn "warn event"
      expect(log.level).to eq(EventLog::LEVELS[:warn])
    end

    it "should create an event with error log level" do
      log = EventLog.error "error event"
      expect(log.level).to eq(EventLog::LEVELS[:error])
    end

    it "should create an event with fatal log level" do
      log = EventLog.fatal "fatal event"
      expect(log.level).to eq(EventLog::LEVELS[:fatal])
    end

    describe "including association" do
      before do
        company = Company.create!(name: "company")
        @user = User.create!(email: "nobody@example.com", first_name: "f", last_name: "l", roles_mask: 4, company: company)
        @customer = Company.create!(name: "customer")
      end

      it "should associate with a user given a model" do
        count = @user.event_logs.count
        EventLog.info "associated with user by model", user: @user
        expect(@user.event_logs.count).to eq(count + 1)
      end

      it "should associate with a user given an id" do
        count = @user.event_logs.count
        EventLog.info "associated with user by id", user_id: @user.id
        expect(@user.event_logs.count).to eq(count + 1)
      end

      it "should associate with a customer given a model" do
        count = @customer.event_logs.count
        EventLog.info "associated with customer by model", customer: @customer
        expect(@customer.event_logs.count).to eq(count + 1)
      end

      it "should associate with a customer given an id" do
        count = @customer.event_logs.count
        log = EventLog.info "associated with customer by id", customer_id: @customer.id
        expect(@customer.event_logs.count).to eq(count + 1)
      end
    end

    describe "event" do
      it "should fail with invalid chars" do
        expect do
          EventLog.info "some event", event: :Test_Event
        end.to raise_error(Mongoid::Errors::Validations)
      end

      it "should succeed with valid chars" do
        EventLog.info "some event", event: :test_event
      end

      it "should set nil as a default" do
        ev = EventLog.info "some event"
        expect(ev.event).to eq(nil)
      end

      it "should symbolize a string" do
        ev = EventLog.info "some event", event: "the_event"
        expect(ev.event).to eq(:the_event)
      end
    end

    describe "data" do
      it "should add extra options to data hash" do
        log = EventLog.info "extra data", event: :my_event, foo: "foo string", bar: :bar_symbol, baz: 999
        expect(log.data).to eq({ foo: '"foo string"', bar: '"bar_symbol"', baz: "999" })
      end

      it "should convert data values to json" do
        action = Action.new(name: "win", color: "green")
        log = EventLog.info "extra data", object: Object.new, hash: {a:1, b:"foo", c: :xyz}, action: action
        expect(JSON.parse(log.data[:object])).to eq({})
        expect(JSON.parse(log.data[:hash])).to eq({"a"=>1, "b"=>"foo", "c"=>"xyz"})
        expect(JSON.parse(log.data[:action])["name"]).to eq("win")
        expect(JSON.parse(log.data[:action])["color"]).to eq("green")
      end
    end

    describe "caller location" do
      it "should include the line number" do
        log = EventLog.info "with line number"
        expect(log.lineno).to eq(__LINE__ - 1)
      end

      it "should include the method (label)" do
        def calling_function; @log = EventLog.info "with label"; end
        calling_function
        expect(@log.label).to eq("calling_function")
      end

      it "should allow manipulating the caller depth" do
        def labelled_caller
          def hidden_log_wrapper
            @log = EventLog.info "deeply nested", depth: 1
          end
          hidden_log_wrapper
        end
        labelled_caller
        expect(@log.label).to eq("labelled_caller")
        # for good measure, make sure depth is deleted, and doesn't wind up in the data hash
        expect(@log.data).to eq({})
      end

      it "should include the path to the file" do
        log = EventLog.info "with path"
        expect(log.path).to eq(__FILE__)
      end

      it "should include a backtrace if warning level or above" do
        def check_backtrace log
          # the backtrace is an array of strings of the form path:lineno:label
          log.backtrace.each do |line|
            expect(line.match(/:[0-9]+:/)).to be_truthy
          end
        end

        [:warn, :error, :fatal].each do |level|
          log = EventLog.send(level, "with backtrace")
          check_backtrace(log)
        end
      end

      it "should not include a backtrace if below warning level" do
        [:success, :info].each do |level|
          log = EventLog.send(level, "with backtrace")
          expect(log.backtrace).to be_nil
        end
      end
    end
  end
end
