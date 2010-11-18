class TestUsersTests < Test::Unit::TestCase
  include Koala

  describe "Koala TestUsers with access token" do
    include LiveTestingDataHelper

    before :all do
      # get oauth data
      @oauth_data = $testing_data["oauth_test_data"]
      @app_id = @oauth_data["app_id"]
      @secret = @oauth_data["secret"]
      @app_access_token = @oauth_data["app_access_token"]
      
      # check OAuth data
      unless @app_id && @secret && @app_access_token
        raise Exception, "Must supply OAuth app id, secret, app_access_token, and callback to run live subscription tests!" 
      end
    end
    
    describe "when initializing" do
      # basic initialization
      it "should initialize properly with an app_id and an app_access_token" do
        test_users = Facebook::TestUsers.new(:app_id => @app_id, :app_access_token => @app_access_token)
        test_users.should be_a(Facebook::TestUsers)
      end
      
      # init with secret / fetching the token
      it "should initialize properly with an app_id and a secret" do 
        test_users = Facebook::TestUsers.new(:app_id => @app_id, :secret => @secret)
        test_users.should be_a(Facebook::TestUsers)      
      end
      
      it "should use the OAuth class to fetch a token when provided an app_id and a secret" do
        oauth = Facebook::OAuth.new(@app_id, @secret)
        token = oauth.get_app_access_token
        oauth.should_receive(:get_app_access_token).and_return(token)
        Facebook::OAuth.should_receive(:new).with(@app_id, @secret).and_return(oauth) 
        test_users = Facebook::TestUsers.new(:app_id => @app_id, :secret => @secret)
      end
    end
    
    describe "when used" do
      before :each do
        @test_users = Facebook::TestUsers.new({:app_access_token => @app_access_token, :app_id => @app_id})
      end

      # TEST USER MANAGEMENT
      it "should create a test user when not given installed" do
        result = @test_users.create(false)
        result.should be_a(Hash)
        (result["id"] && result["access_token"] && result["login_url"]).should
      end
      
      it "should create a test user when not given installed, ignoring permissions" do
        result = @test_users.create(false, "read_stream")
        result.should be_a(Hash)
        (result["id"] && result["access_token"] && result["login_url"]).should
      end
      
      it "should create a test user when given installed and a permission" do
        result = @test_users.create(true, "read_stream")
        result.should be_a(Hash)
        (result["id"] && result["access_token"] && result["login_url"]).should
      end
      
      describe "with a user to delete" do
        before :each do
          @user1 = @test_users.create(true, "read_stream")
          @user2 = @test_users.create(true, "read_stream,user_interests")
        end
        
        it "should delete a user by id" do
          @test_users.delete(@user1['id'])
        end
        
        it "should delete a user by hash" do
          @test_users.delete(@user2)
        end
        
      end
      
      describe "with existing users" do
        before :each do
          @user1 = @test_users.create(true, "read_stream")
          @user2 = @test_users.create(true, "read_stream,user_interests")
        end
        
        after :each do
          @test_users.delete(@user1)
          @test_users.delete(@user2)
        end
      
        it "should list test users" do
          result = @test_users.list
          result.should be_a(Hash)
          data = result["data"]
          data.should be_a(Array)
          first_user, second_user = data[0], data[1]
          (first_user["id"] && first_user["access_token"] && first_user["login_url"]).should
          (second_user["id"] && second_user["access_token"] && second_user["login_url"]).should
        end
        
      end # with existing users
      
    end # when used

  end  # describe Koala TestUsers
end # class