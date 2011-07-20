require 'spec_helper'

describe "Koala::Facebook::OAuth" do
  before :each do
    # make the relevant test data easily accessible
    @oauth_data = $testing_data["oauth_test_data"]
    @app_id = @oauth_data["app_id"]
    @secret = @oauth_data["secret"]
    @code = @oauth_data["code"]
    @callback_url = @oauth_data["callback_url"]
    @raw_token_string = @oauth_data["raw_token_string"]
    @raw_offline_access_token_string = @oauth_data["raw_offline_access_token_string"]
    
    # for signed requests (http://developers.facebook.com/docs/authentication/canvas/encryption_proposal)
    @signed_params = @oauth_data["signed_params"]
    @signed_params_result = @oauth_data["signed_params_result"]
    
    # this should expanded to cover all variables
    raise Exception, "Must supply app data to run FacebookOAuthTests!" unless @app_id && @secret && @callback_url && 
                                                                              @raw_token_string && 
                                                                              @raw_offline_access_token_string

    # we can just test against the same key twice
    @multiple_session_keys = [@oauth_data["session_key"], @oauth_data["session_key"]] if @oauth_data["session_key"]

    @oauth = Koala::Facebook::OAuth.new(@app_id, @secret, @callback_url)

    @time = Time.now
    Time.stub!(:now).and_return(@time)
    @time.stub!(:to_i).and_return(1273363199)
  end
  
  # initialization
  it "should properly initialize" do
    @oauth.should
  end

  it "should properly set attributes" do
    (@oauth.app_id == @app_id && 
      @oauth.app_secret == @secret && 
      @oauth.oauth_callback_url == @callback_url).should be_true
  end

  it "should properly initialize without a callback_url" do
    @oauth = Koala::Facebook::OAuth.new(@app_id, @secret)
  end

  it "should properly set attributes without a callback URL" do
    @oauth = Koala::Facebook::OAuth.new(@app_id, @secret)
    (@oauth.app_id == @app_id && 
      @oauth.app_secret == @secret && 
      @oauth.oauth_callback_url == nil).should be_true
  end
  
  describe "for cookie parsing" do
    describe "get_user_info_from_cookies" do
      it "should properly parse valid cookies" do
        result = @oauth.get_user_info_from_cookies(@oauth_data["valid_cookies"])
        result.should be_a(Hash)
      end
  
      it "should return all the cookie components from valid cookie string" do
        cookie_data = @oauth_data["valid_cookies"]
        parsing_results = @oauth.get_user_info_from_cookies(cookie_data)
        number_of_components = cookie_data["fbs_#{@app_id.to_s}"].scan(/\=/).length
        parsing_results.length.should == number_of_components
      end

      it "should properly parse valid offline access cookies (e.g. no expiration)" do 
        result = @oauth.get_user_info_from_cookies(@oauth_data["offline_access_cookies"])
        result["uid"].should      
      end

      it "should return all the cookie components from offline access cookies" do
        cookie_data = @oauth_data["offline_access_cookies"]
        parsing_results = @oauth.get_user_info_from_cookies(cookie_data)
        number_of_components = cookie_data["fbs_#{@app_id.to_s}"].scan(/\=/).length
        parsing_results.length.should == number_of_components
      end

      it "shouldn't parse expired cookies" do
        result = @oauth.get_user_info_from_cookies(@oauth_data["expired_cookies"])
        result.should be_nil
      end
  
      it "shouldn't parse invalid cookies" do
        # make an invalid string by replacing some values
        bad_cookie_hash = @oauth_data["valid_cookies"].inject({}) { |hash, value| hash[value[0]] = value[1].gsub(/[0-9]/, "3") }
        result = @oauth.get_user_info_from_cookies(bad_cookie_hash)
        result.should be_nil
      end
    end
    
    describe "get_user_from_cookies" do
      it "should use get_user_info_from_cookies to parse the cookies" do
        data = @oauth_data["valid_cookies"]
        @oauth.should_receive(:get_user_info_from_cookies).with(data).and_return({})
        @oauth.get_user_from_cookies(data)
      end

      it "should use return a string if the cookies are valid" do
        result = @oauth.get_user_from_cookies(@oauth_data["valid_cookies"])
        result.should be_a(String)
      end
      
      it "should return nil if the cookies are invalid" do
        # make an invalid string by replacing some values
        bad_cookie_hash = @oauth_data["valid_cookies"].inject({}) { |hash, value| hash[value[0]] = value[1].gsub(/[0-9]/, "3") }
        result = @oauth.get_user_from_cookies(bad_cookie_hash)
        result.should be_nil
      end        
    end
  end
  
  # OAuth URLs
  
  describe "for URL generation" do

    describe "for OAuth codes" do 
      # url_for_oauth_code
      it "should generate a properly formatted OAuth code URL with the default values" do 
        url = @oauth.url_for_oauth_code
        url.should == "https://#{Koala::Facebook::GRAPH_SERVER}/oauth/authorize?client_id=#{@app_id}&redirect_uri=#{@callback_url}"
      end

      it "should generate a properly formatted OAuth code URL when a callback is given" do 
        callback = "foo.com"
        url = @oauth.url_for_oauth_code(:callback => callback)
        url.should == "https://#{Koala::Facebook::GRAPH_SERVER}/oauth/authorize?client_id=#{@app_id}&redirect_uri=#{callback}"
      end

      it "should generate a properly formatted OAuth code URL when permissions are requested as a string" do 
        permissions = "publish_stream,read_stream"
        url = @oauth.url_for_oauth_code(:permissions => permissions)
        url.should == "https://#{Koala::Facebook::GRAPH_SERVER}/oauth/authorize?client_id=#{@app_id}&redirect_uri=#{@callback_url}&scope=#{permissions}"
      end

      it "should generate a properly formatted OAuth code URL when permissions are requested as a string" do 
        permissions = ["publish_stream", "read_stream"]
        url = @oauth.url_for_oauth_code(:permissions => permissions)
        url.should == "https://#{Koala::Facebook::GRAPH_SERVER}/oauth/authorize?client_id=#{@app_id}&redirect_uri=#{@callback_url}&scope=#{permissions.join(",")}"
      end

      it "should generate a properly formatted OAuth code URL when both permissions and callback are provided" do 
        permissions = "publish_stream,read_stream"
        callback = "foo.com"
        url = @oauth.url_for_oauth_code(:callback => callback, :permissions => permissions)
        url.should == "https://#{Koala::Facebook::GRAPH_SERVER}/oauth/authorize?client_id=#{@app_id}&redirect_uri=#{callback}&scope=#{permissions}"
      end

      it "should generate a properly formatted OAuth code URL when a display is given as a string" do 
        url = @oauth.url_for_oauth_code(:display => "page")
        url.should == "https://#{Koala::Facebook::GRAPH_SERVER}/oauth/authorize?client_id=#{@app_id}&redirect_uri=#{@callback_url}&display=page"
      end

      it "should raise an exception if no callback is given in initialization or the call" do 
        oauth2 = Koala::Facebook::OAuth.new(@app_id, @secret)
        lambda { oauth2.url_for_oauth_code }.should raise_error(ArgumentError)
      end
    end
  
    describe "for access token URLs" do
      before :each do
        # since we're just composing a URL here, we don't need to have a real code
        @code ||= "test_code"
      end
      
      # url_for_access_token
      it "should generate a properly formatted OAuth token URL when provided a code" do 
        url = @oauth.url_for_access_token(@code)
        url.should == "https://#{Koala::Facebook::GRAPH_SERVER}/oauth/access_token?client_id=#{@app_id}&redirect_uri=#{@callback_url}&client_secret=#{@secret}&code=#{@code}"
      end

      it "should generate a properly formatted OAuth token URL when provided a callback" do 
        callback = "foo.com"
        url = @oauth.url_for_access_token(@code, :callback => callback)
        url.should == "https://#{Koala::Facebook::GRAPH_SERVER}/oauth/access_token?client_id=#{@app_id}&redirect_uri=#{callback}&client_secret=#{@secret}&code=#{@code}"
      end
    end
  end

  describe "for fetching access tokens" do 
    if $testing_data['oauth_test_data']['code']
      describe "get_access_token_info" do
        it "should properly get and parse an access token token results into a hash" do
          result = @oauth.get_access_token_info(@code)
          result.should be_a(Hash)
        end

        it "should properly include the access token results" do
          result = @oauth.get_access_token_info(@code)
          result["access_token"].should
        end

        it "should raise an error when get_access_token is called with a bad code" do
          lambda { @oauth.get_access_token_info("foo") }.should raise_error(Koala::Facebook::APIError) 
        end
      end

      describe "get_access_token" do
        it "should use get_access_token_info to get and parse an access token token results" do
          result = @oauth.get_access_token(@code)
          result.should be_a(String)
        end

        it "should return the access token as a string" do
          result = @oauth.get_access_token(@code)
          original = @oauth.get_access_token_info(@code)
          result.should == original["access_token"]
        end

        it "should raise an error when get_access_token is called with a bad code" do
          lambda { @oauth.get_access_token("foo") }.should raise_error(Koala::Facebook::APIError) 
        end

        it "should pass on any options provided to make_request" do
          options = {:a => 2}
          Koala.should_receive(:make_request).with(anything, anything, anything, hash_including(options)).and_return(Koala::Response.new(200, "", {}))
          @oauth.get_access_token(@code, options)
        end
      end
    else
      it "OAuth code tests will not be run since the code field in facebook_data.yml is blank."      
    end

    describe "get_app_access_token_info" do
      it "should properly get and parse an app's access token as a hash" do
        result = @oauth.get_app_access_token_info
        result.should be_a(Hash)
      end
        
      it "should include the access token" do
        result = @oauth.get_app_access_token_info
        result["access_token"].should
      end
      
      it "should pass on any options provided to make_request" do
        options = {:a => 2}
        Koala.should_receive(:make_request).with(anything, anything, anything, hash_including(options)).and_return(Koala::Response.new(200, "", {}))
        @oauth.get_app_access_token_info(options)
      end
    end
  
    describe "get_app_acess_token" do
      it "should use get_access_token_info to get and parse an access token token results" do
        result = @oauth.get_app_access_token
        result.should be_a(String)
      end

      it "should return the access token as a string" do
        result = @oauth.get_app_access_token
        original = @oauth.get_app_access_token_info
        result.should == original["access_token"]
      end
      
      it "should pass on any options provided to make_request" do
        options = {:a => 2}
        Koala.should_receive(:make_request).with(anything, anything, anything, hash_including(options)).and_return(Koala::Response.new(200, "", {}))
        @oauth.get_app_access_token(options)
      end
    end
    
    describe "protected methods" do
    
      # protected methods
      # since these are pretty fundamental and pretty testable, we want to test them

      # parse_access_token
      it "should properly parse access token results" do
        result = @oauth.send(:parse_access_token, @raw_token_string)
        has_both_parts = result["access_token"] && result["expires"]
        has_both_parts.should
      end

      it "should properly parse offline access token results" do
        result = @oauth.send(:parse_access_token, @raw_offline_access_token_string)
        has_both_parts = result["access_token"] && !result["expires"]
        has_both_parts.should
      end

      # fetch_token_string
      # somewhat duplicative with the tests for get_access_token and get_app_access_token
      # but no harm in thoroughness
      if $testing_data["oauth_test_data"]["code"]
        it "should fetch a proper token string from Facebook when given a code" do
          result = @oauth.send(:fetch_token_string, :code => @code, :redirect_uri => @callback_url)
          result.should =~ /^access_token/
        end
      else
        it "fetch_token_string code test will not be run since the code field in facebook_data.yml is blank."
      end

      it "should fetch a proper token string from Facebook when asked for the app token" do
        result = @oauth.send(:fetch_token_string, {:type => 'client_cred'}, true)
        result.should =~ /^access_token/
      end
    end
  end

  describe "for exchanging session keys" do
    if $testing_data["oauth_test_data"]["session_key"]
      describe "with get_token_info_from_session_keys" do
        it "should get an array of session keys from Facebook when passed a single key" do
          result = @oauth.get_tokens_from_session_keys([@oauth_data["session_key"]])
          result.should be_an(Array)
          result.length.should == 1
        end

        it "should get an array of session keys from Facebook when passed multiple keys" do
          result = @oauth.get_tokens_from_session_keys(@multiple_session_keys)
          result.should be_an(Array)
          result.length.should == 2
        end
    
        it "should return the original hashes" do
          result = @oauth.get_token_info_from_session_keys(@multiple_session_keys)
          result[0].should be_a(Hash)
        end
    
        it "should properly handle invalid session keys" do
          result = @oauth.get_token_info_from_session_keys(["foo", "bar"])
          #it should return nil for each of the invalid ones
          result.each {|r| r.should be_nil}
        end
    
        it "should properly handle a mix of valid and invalid session keys" do
          result = @oauth.get_token_info_from_session_keys(["foo"].concat(@multiple_session_keys))
          # it should return nil for each of the invalid ones
          result.each_with_index {|r, index| index > 0 ? r.should(be_a(Hash)) : r.should(be_nil)}
        end
    
        it "should throw an APIError if Facebook returns an empty body (as happens for instance when the API breaks)" do
          @oauth.should_receive(:fetch_token_string).and_return("")
          lambda { @oauth.get_token_info_from_session_keys(@multiple_session_keys) }.should raise_error(Koala::Facebook::APIError)
        end
    
        it "should pass on any options provided to make_request" do
          options = {:a => 2}
          Koala.should_receive(:make_request).with(anything, anything, anything, hash_including(options)).and_return(Koala::Response.new(200, "[{}]", {}))
          @oauth.get_token_info_from_session_keys([], options)
        end
      end
  
      describe "with get_tokens_from_session_keys" do
        it "should call get_token_info_from_session_keys" do
          args = @multiple_session_keys
          @oauth.should_receive(:get_token_info_from_session_keys).with(args, anything).and_return([])
          @oauth.get_tokens_from_session_keys(args)
        end
    
        it "should return an array of strings" do
          args = @multiple_session_keys
          result = @oauth.get_tokens_from_session_keys(args)
          result.each {|r| r.should be_a(String) }
        end
    
        it "should properly handle invalid session keys" do
          result = @oauth.get_tokens_from_session_keys(["foo", "bar"])
          # it should return nil for each of the invalid ones
          result.each {|r| r.should be_nil}
        end
    
        it "should properly handle a mix of valid and invalid session keys" do
          result = @oauth.get_tokens_from_session_keys(["foo"].concat(@multiple_session_keys))
          # it should return nil for each of the invalid ones
          result.each_with_index {|r, index| index > 0 ? r.should(be_a(String)) : r.should(be_nil)}
        end
    
        it "should pass on any options provided to make_request" do
          options = {:a => 2}
          Koala.should_receive(:make_request).with(anything, anything, anything, hash_including(options)).and_return(Koala::Response.new(200, "[{}]", {}))
          @oauth.get_tokens_from_session_keys([], options)
        end
      end

      describe "get_token_from_session_key" do
        it "should call get_tokens_from_session_keys when the get_token_from_session_key is called" do
          key = @oauth_data["session_key"]
          @oauth.should_receive(:get_tokens_from_session_keys).with([key], anything).and_return([])
          @oauth.get_token_from_session_key(key)
        end

        it "should get back the access token string from get_token_from_session_key" do
          result = @oauth.get_token_from_session_key(@oauth_data["session_key"])
          result.should be_a(String)
        end

        it "should be the first value in the array" do
          result = @oauth.get_token_from_session_key(@oauth_data["session_key"])
          array = @oauth.get_tokens_from_session_keys([@oauth_data["session_key"]])
          result.should == array[0]
        end
    
        it "should properly handle an invalid session key" do
          result = @oauth.get_token_from_session_key("foo")
          result.should be_nil
        end
    
        it "should pass on any options provided to make_request" do
          options = {:a => 2}
          Koala.should_receive(:make_request).with(anything, anything, anything, hash_including(options)).and_return(Koala::Response.new(200, "[{}]", {}))
          @oauth.get_token_from_session_key("", options)
        end
      end
    else
      it "Session key exchange tests will not be run since the session key in facebook_data.yml is blank."  
    end
  end
  
  describe "for parsing signed requests" do
    # the signed request code is ported directly from Facebook
    # so we only need to test at a high level that it works      
    it "should throw an error if the algorithm is unsupported" do
      MultiJson.stub(:decode).and_return("algorithm" => "my fun algorithm")
      lambda { @oauth.parse_signed_request(@signed_request) }.should raise_error
    end
    
    it "should throw an error if the signature is invalid" do
      OpenSSL::HMAC.stub!(:hexdigest).and_return("i'm an invalid signature")
      lambda { @oauth.parse_signed_request(@signed_request) }.should raise_error
    end

    it "properly parses requests" do
      @oauth = Koala::Facebook::OAuth.new(@app_id, @secret || @app_secret)
      @oauth.parse_signed_request(@signed_params).should == @signed_params_result
    end
  end

end # describe