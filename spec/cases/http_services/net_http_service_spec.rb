require 'spec_helper'


Horse = Koala::NetHTTPService

describe "NetHTTPService module holder class Horse" do
  before :each do
    # reset the always_use_ssl parameter
    Horse.always_use_ssl = nil
  end

  it "should define a make_request static module method" do
    Horse.respond_to?(:make_request).should be_true
  end

  it "should include the Koala::HTTPService module defining common features" do
    Horse.included_modules.include?(Koala::HTTPService).should be_true
  end

  describe "when making a request" do
    before(:each) do
      # Setup stubs for make_request to execute without exceptions
      @mock_http_response = stub('Net::HTTPResponse', :code => 1)
      @mock_body = stub('Net::HTTPResponse body')
      @http_request_result = [@mock_http_response, @mock_body]

      # to_ary is called in Ruby 1.9 to provide backwards compatibility
      # with the response, body = http.get() syntax we use
      @mock_http_response.stub!(:to_ary).and_return(@http_request_result)

      @http_yield_mock = mock('Net::HTTP start yielded object')

      @http_yield_mock.stub(:post).and_return(@http_request_result)
      @http_yield_mock.stub(:get).and_return(@http_request_result)

      @http_mock = stub('Net::HTTP object', 'use_ssl=' => true, 'verify_mode=' => true)
      @http_mock.stub(:start).and_yield(@http_yield_mock)
      @http_mock.stub(:ca_path=)
      @http_mock.stub(:ca_file=)      

      Net::HTTP.stub(:new).and_return(@http_mock)
    end

    describe "the connection" do
      it "should use POST if verb is not GET" do
        @http_yield_mock.should_receive(:post).and_return(@mock_http_response)
        @http_mock.should_receive(:start).and_yield(@http_yield_mock)

        Horse.make_request('anything', {}, 'anything')
      end

      it "should use GET if that verb is specified" do
        @http_yield_mock.should_receive(:get).and_return(@mock_http_response)
        @http_mock.should_receive(:start).and_yield(@http_yield_mock)

        Horse.make_request('anything', {}, 'get')
      end

      it "should add the method to the arguments if it's not get or post" do
        args = {}
        method = "telekenesis"
        # since the arguments get encoded later, we'll test for merge!
        # even though that's somewhat testing internal implementation
        args.should_receive(:merge!).with(:method => method)

        Horse.make_request('anything', args, method)
      end
    end

    describe "if the request has an access token" do
      before :each do
        @args = {"access_token" => "123"}
      end

      it "should use SSL" do
        @http_mock.should_receive('use_ssl=').with(true)

        Horse.make_request('anything', @args, 'anything')
      end

      it "should set the port to 443" do
        Net::HTTP.should_receive(:new).with(anything, 443).and_return(@http_mock)

        Horse.make_request('anything', @args, 'anything')
      end
    end
    
    describe "if always_use_ssl is true" do
      before :each do
        Horse.always_use_ssl = true
      end

      it "should use SSL" do
        @http_mock.should_receive('use_ssl=').with(true)

        Horse.make_request('anything', {}, 'anything')
      end

      it "should set the port to 443" do
        Net::HTTP.should_receive(:new).with(anything, 443).and_return(@http_mock)

        Horse.make_request('anything', {}, 'anything')
      end
    end

    describe "if the use_ssl option is provided" do
      it "should use SSL" do
        @http_mock.should_receive('use_ssl=').with(true)

        Horse.make_request('anything', {}, 'anything', :use_ssl => true)
      end

      it "should set the port to 443" do
        Net::HTTP.should_receive(:new).with(anything, 443).and_return(@http_mock)

        Horse.make_request('anything', {}, 'anything', :use_ssl => true)
      end
    end

    describe "if there's no token and always_use_ssl isn't true" do
      it "should not use SSL" do
        @http_mock.should_not_receive('use_ssl=')
        Horse.make_request('anything', {}, 'anything')
      end

      it "should not set the port" do
        Net::HTTP.should_receive(:new).with(anything, nil).and_return(@http_mock)
        Horse.make_request('anything', {}, 'anything')
      end
    end
    
    describe "proxy options" do
      before :each do
        Horse.proxy = "http://defaultproxy"
      end
      after :all do
        Horse.proxy = nil
      end

      it "should use passed proxy option if provided" do
        Net::HTTP.should_receive(:new).with(Koala::Facebook::GRAPH_SERVER, anything, "passedproxy", 80, nil, nil).and_return(@http_mock)
        Horse.make_request('anything', {} , 'anything', {:proxy => "http://passedproxy"})
      end
      
      it "should use default proxy if default is provided and NO proxy option passed" do
        Net::HTTP.should_receive(:new).with(Koala::Facebook::GRAPH_SERVER, anything, "defaultproxy", 80, nil, nil).and_return(@http_mock)
        Horse.make_request('anything', {} , 'anything', {})
      end
      
      it "should NOT use a proxy if default is NOT provided and NO proxy option passed" do
        Horse.proxy = nil
        Net::HTTP.should_receive(:new).with(Koala::Facebook::GRAPH_SERVER, anything).and_return(@http_mock)
        Horse.make_request('anything', {} , 'anything', {})
      end
    end
    
    describe "timeout options" do
      before :each do
        Horse.timeout = 20 # seconds
      end
      after :all do
        Horse.timeout = nil # seconds
      end

      it "should use passed timeout option if provided" do
        @http_mock.should_receive('open_timeout=').with(10)
        @http_mock.should_receive('read_timeout=').with(10)
        Horse.make_request('anything', {} , 'anything', {:timeout => 10})
      end
      
      it "should use default timout if default is provided and NO timeout option passed" do
        @http_mock.should_receive('open_timeout=').with(20)
        @http_mock.should_receive('read_timeout=').with(20)
        Horse.make_request('anything', {} , 'anything', {})
      end
      
      it "should NOT use a timeout if default is NOT provided and NO timeout option passed" do
        Horse.timeout = nil # seconds
        @http_mock.should_not_receive('open_timeout=')
        @http_mock.should_not_receive('read_timeout=')
        Horse.make_request('anything', {} , 'anything', {})
      end
    end
    
    describe "ca_file options" do
      after :each do
        Horse.always_use_ssl = nil
        Horse.ca_file = nil
      end
      
      it "should not use a ca_file if the request is not via SSL" do
        Horse.always_use_ssl = false  
        @http_mock.should_not_receive(:ca_file=)
        Horse.make_request('anything', {} , 'anything', {:ca_file => '/no/file'})
      end
      
      describe "when via SSL" do
        before :each do
          Horse.always_use_ssl = true
          
          @global_ca_file_path = '/global/ca/file/path'
          File.stub(:exists?).and_return(true)
        end

        it "should not use a default ca_file if the default ca_file does not exist" do
          Horse.ca_file = @global_ca_file_path
          
          File.should_receive(:exists?).with(@global_ca_file_path).and_return(false)
          Horse.should_not_receive(:ca_file=).with(@global_ca_file_path)
          
          Horse.make_request('anything', {} , 'anything', {})
        end
        
        it "should use passed ca_file options if provided" do
          given_ca_file = '/ca/file'
          
          Horse.ca_file = @global_ca_file_path
          @http_mock.should_not_receive(:ca_file=).with(@global_ca_file_path)
          @http_mock.should_receive(:ca_file=).with(given_ca_file)
          
          Horse.make_request('anything', {} , 'anything', {:ca_file => given_ca_file})
        end
        
        it "should use default ca_file if default is provided and NO ca_file option is passed" do
          Horse.ca_file = @global_ca_file_path
          @http_mock.should_receive(:ca_file=).with(@global_ca_file_path)
          
          Horse.make_request('anything', {} , 'anything', {})
        end
        
        it "should NOT use a ca_file if default is NOT provided and NO ca_file option is passed" do
          @http_mock.should_not_receive(:ca_file=)
          
          Horse.make_request('anything', {} , 'anything', {})          
        end
      end
    end
    
    describe "ca_path options" do
      after :each do
        Horse.always_use_ssl = nil
        Horse.ca_path = nil
      end
      
      it "should not use a ca_path if the request is not via SSL" do
        Horse.always_use_ssl = false  
        @http_mock.should_not_receive('ca_path=')
        Horse.make_request('anything', {} , 'anything', {:ca_file => '/no/file'})
      end
      
      describe "when via SSL" do
        before :each do
          Horse.always_use_ssl = true
          
          @global_ca_path = '/global/ca/path'
          Dir.stub(:exists?).and_return(true)
        end

        it "should not use a default ca_path if the default ca_path does not exist" do
          Horse.ca_path = @global_ca_path
          
          Dir.should_receive(:exists?).with(@global_ca_path).and_return(false)
          Horse.should_not_receive(:ca_path=).with(@global_ca_path)
          
          Horse.make_request('anything', {} , 'anything', {})
        end
        
        it "should use passed ca_path options if provided" do
          given_ca_path = '/ca/path'
          
          Horse.ca_path = @global_ca_path
          @http_mock.should_not_receive(:ca_ath=).with(@global_ca_path)
          @http_mock.should_receive(:ca_path=).with(given_ca_path)
          
          Horse.make_request('anything', {} , 'anything', {:ca_path => given_ca_path})
        end
        
        it "should use default ca_path if default is provided and NO ca_path option is passed" do
          Horse.ca_path = @global_ca_path
          @http_mock.should_receive(:ca_path=).with(@global_ca_path)
          
          Horse.make_request('anything', {} , 'anything', {})
        end
        
        it "should NOT use a ca_path if default is NOT provided and NO ca_path option is passed" do
          @http_mock.should_not_receive(:ca_path=)
          
          Horse.make_request('anything', {} , 'anything', {})          
        end
      end
    end    
    
    it "should use the graph server by default" do
      Net::HTTP.should_receive(:new).with(Koala::Facebook::GRAPH_SERVER, anything).and_return(@http_mock)
      Horse.make_request('anything', {}, 'anything')
    end

    it "should use the REST server if the :rest_api option is true" do
      Net::HTTP.should_receive(:new).with(Koala::Facebook::REST_SERVER, anything).and_return(@http_mock)
      Horse.make_request('anything', {}, 'anything', :rest_api => true)
    end

    it "no longer sets verify_mode to no verification" do
      @http_mock.should_not_receive('verify_mode=')

      Horse.make_request('anything', {}, 'anything')
    end

    it "should start an HTTP connection" do
      @http_mock.should_receive(:start).and_yield(@http_yield_mock)
      Horse.make_request('anything', {}, 'anything')
    end
    
    it 'creates a HTTP Proxy object when options contain a proxy' do
      Net::HTTP.should_receive(:new).with(anything, anything, 'proxy', 1234, 'user', 'pass').and_return(@http_mock)
      Horse.make_request('anything', {}, 'anything', {:proxy => 'http://user:pass@proxy:1234'})
    end

    it 'sets both timeouts when options contains a timeout' do
      @http_mock.should_receive(:open_timeout=).with(10)
      @http_mock.should_receive(:read_timeout=).with(10)
      Horse.make_request('anything', {}, 'anything', {:timeout => 10})
    end

    describe "via POST" do
      it "should use Net::HTTP to make a POST request" do
        @http_yield_mock.should_receive(:post).and_return(@http_request_result)

        Horse.make_request('anything', {}, 'post')
      end

      it "should go to the specified path adding a / if it doesn't exist" do
        path = mock('Path')
        @http_yield_mock.should_receive(:post).with(path, anything).and_return(@http_request_result)

        Horse.make_request(path, {}, 'post')
      end

      it "should use encoded parameters" do
        args = {}
        params = mock('Encoded parameters')
        Horse.should_receive(:encode_params).with(args).and_return(params)

        @http_yield_mock.should_receive(:post).with(anything, params).and_return(@http_request_result)

        Horse.make_request('anything', args, 'post')
      end

      describe "with multipart/form-data" do
        before(:each) do
          Horse.stub(:encode_multipart_params)
          Horse.stub("params_require_multipart?").and_return(true)

          @multipart_request_stub = stub('Stub Multipart Request')
          Net::HTTP::Post::Multipart.stub(:new).and_return(@multipart_request_stub)

          @file_stub = stub('fake File', "kind_of?" => true, "path" => 'anypath.jpg')

          @http_yield_mock.stub(:request).with(@multipart_request_stub).and_return(@http_request_result)
        end

        it "should use multipart/form-data if any parameter is a valid file hash" do
          @http_yield_mock.should_receive(:request).with(@multipart_request_stub).and_return(@http_request_result)

          Horse.make_request('anything', {}, 'post')
        end

        it "should use the given request path for the request" do
          args = {"file" => @file_stub}
          expected_path = 'expected/path'

          Net::HTTP::Post::Multipart.should_receive(:new).with(expected_path, anything).and_return(@multipart_request_stub)

          Horse.make_request(expected_path, {}, 'post')
        end

        it "should use multipart encoded arguments for the request" do
          args = {"file" => @file_stub}
          expected_params = stub('Stub Multipart Params')

          Horse.should_receive(:encode_multipart_params).with(args).and_return(expected_params)
          Net::HTTP::Post::Multipart.should_receive(:new).with(anything, expected_params).and_return(@multipart_request_stub)

          Horse.make_request('anything', args, 'post')
        end
      end
    end

    describe "via GET" do
      it "should use Net::HTTP to make a GET request" do
        @http_yield_mock.should_receive(:get).and_return(@http_request_result)

        Horse.make_request('anything', {}, 'get')
      end

      it "should use the correct path, including arguments" do
        path = mock('Path')
        params = mock('Encoded parameters')
        args = {}

        Horse.should_receive(:encode_params).with(args).and_return(params)
        @http_yield_mock.should_receive(:get).with("#{path}?#{params}").and_return(@http_request_result)

        Horse.make_request(path, args, 'get')
      end
    end

    describe "the returned value" do
      before(:each) do
        @response = Horse.make_request('anything', {}, 'anything')
      end

      it "should return a Koala::Response object" do
        @response.class.should == Koala::Response
      end

      it "should return a Koala::Response with the right status" do
        @response.status.should == @mock_http_response.code
      end

      it "should reutrn a Koala::Response with the right body" do
        @response.body.should == @mock_body
      end

      it "should return a Koala::Response with the Net::HTTPResponse object as headers" do
        @response.headers.should == @mock_http_response
      end
    end # describe return value
  end # describe when making a request

  describe "when detecting if multipart posting is needed" do
    it "should be true if any parameter value requires multipart post" do
      koala_io = mock("Koala::IO")
      koala_io.should_receive(:kind_of?).with(Koala::UploadableIO).and_return(true)

      args = {
        "key1" => "val",
        "key2" => "val",
        "key3" => koala_io,
        "key4" => "val"
      }

      Horse.params_require_multipart?(args).should be_true
    end
    
    describe "when encoding multipart/form-data params" do
      it "should replace Koala::UploadableIO values with UploadIO values" do
        upload_io = UploadIO.new(__FILE__, "fake type")
        
        uploadable_io = stub('Koala::UploadableIO')
        uploadable_io.should_receive(:kind_of?).with(Koala::UploadableIO).and_return(true)
        uploadable_io.should_receive(:to_upload_io).and_return(upload_io)
        args = {
          "not_a_file" => "not a file",
          "file" => uploadable_io
        }
        
        result = Horse.encode_multipart_params(args)

        result["not_a_file"] == args["not_a_file"]
        result["file"] == upload_io
      end
    end
    
  end
end