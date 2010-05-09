Koala
====
Koala (<a href="http://github.com/arsduo/koala" target="_blank">http://github.com/arsduo/koala</a>) is a new Facebook Graph library for Ruby.  We wrote Koala with four goals: 

* Lightweight: Koala should be as light and simple as Facebook’s own new libraries, providing API accessors and returning simple JSON.  (We clock in, with comments, just over 300 lines of code.)
* Fast: Koala should, out of the box, be quick. In addition to supporting the vanilla Ruby networking libraries, it natively supports Typhoeus, our preferred gem for making fast HTTP requests. Of course, That brings us to our next topic:
* Flexible: Koala should be useful to everyone, regardless of their current configuration.  (We have no dependencies beyond the JSON gem.  Koala also has a built-in mechanism for using whichever HTTP library you prefer to make requests against the graph.)
* Tested: Koala should have complete test coverage, so you can rely on it.  (By the time you read this the final tests are being written.)

Basic usage:

    graph = Koala::Facebook::GraphAPI.new(oauth_access_token)
    profile = graph.get_object("me")
    friends = graph.get_connections("me", "friends")
    graph.put_object("me", "feed", :message => "I am writing on my wall!")

If you're using Koala within a web application with the Facebook
[JavaScript SDK](http://github.com/facebook/connect-js), you can use the Koala::Facebook::OAuth class 
to parse the cookies set by the JavaScript SDK for logged in users.

Examples and More Details 
-----
There's a very detailed description and walkthrough of Koala at <a href="http://blog.twoalex.com/2010/05/03/introducing-koala-a-new-gem-for-facebooks-new-graph-api/">http://blog.twoalex.com/2010/05/03/introducing-koala-a-new-gem-for-facebooks-new-graph-api/</a>.

You can easily generate OAuth access tokens and any other data needed to play with the Graph API or OAuth at the Koala-powered <a href="http://oauth.twoalex.com" target="_blank">OAuth Playground</a>.


Testing
-----

Unit tests are provided for all of Koala's methods; however, because the OAuth access tokens and cookies expire, you have to provide some of your own data: a valid OAuth access token with publish_stream and read_stream permissions and an OAuth code that can be used to generate an access token.  (The file also provides valid values for other tests, which you're welcome to sub out for data specific to your own application.)

Insert the required values into the file test/facebook_data.yml, then run the test as follows:
    spec koala_tests.rb
    

Known Issues
-----
1. gem install koala produces "Could not find main page readme.md" message