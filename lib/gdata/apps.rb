$:.unshift(File.expand_path(File.dirname(__FILE__))) unless
$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'cgi'
require 'thread'

require 'gdata/apps/provisioning'
require 'gdata/apps/email'

module GData #:nodoc:
   class GApps
      @@google_host = 'apps-apis.google.com'
      @@google_port = 443

      # authentication token, valid up to 24 hours after the last connection
      attr_reader :token, :domain
      attr_reader :provision, :mail
      
      # Creates a new Apps object
      #
      #       user : Google Apps domain administrator username (string)
      #       domain : Google Apps domain (string)
      #       passwd : Google Apps domain administrator password (string)
      #       proxy : (optional) host name, or IP, of the proxy (string)
      #       proxy_port : (optional) proxy port number (numeric)
      #       proxy_user : (optional) login for authenticated proxy only (string)
      #       proxy_passwd : (optional) password for authenticated proxy only (string)
      #
      #  The domain name is extracted from the mail param value.
      #
      # Examples :
      #       standard : no proxy
      #       myapps = ProvisioningApi.new('root@mydomain.com','PaSsWoRd')
      #       proxy :
      #       myapps = ProvisioningApi.new('root@mydomain.com','PaSsWoRd','domain.proxy.com',8080)
      #       authenticated proxy :
      #       myapps = ProvisioningApi.new('root@mydomain.com','PaSsWoRd','domain.proxy.com',8080,'foo','bAr')
      def initialize(user, passwd, proxy=nil, proxy_port=nil, proxy_user=nil, proxy_passwd=nil)
         @domain = user.split('@')[1]
         @actions = Hash.new
         @actions[:domain_login] = {:method => 'POST', :path => '/accounts/ClientLogin' }
         @proxy = proxy
         @proxy_port = proxy_port
         @proxy_user = proxy_user
         @proxy_passwd = proxy_passwd
         @token = login(user, passwd)
         # Reset the connection for thread safety, it only costs one more connection creation, but 
         # it makes the token shared and things avoid ickyness.
         Thread.current[:connection] = nil
         @headers = {'Content-Type'=>'application/atom+xml', 'Authorization'=> 'GoogleLogin auth='+token}
         @provision = GData::Apps::Provisioning.new(self)
         @mail = GData::Apps::Email.new(self)
         return @connection
      end
      
      def recreate_connection
      end
      
      def register_action(method, action)
         if @actions.has_key?(method)
            return -1
         else
            @actions[method] = action
         end
      end

      # Sends credentials and returns an authentication token
      def login(mail, passwd)
         mesg = '&Email='+CGI.escape(mail)+'&Passwd='+CGI.escape(passwd)+'&accountType=HOSTED&service=apps'
         res = request(:domain_login, nil, mesg, {'Content-Type'=>'application/x-www-form-urlencoded'})
         return /^Auth=(.+)$/.match(res.to_s)[1]
         # res.to_s needed, because res.class = REXML::Document
      end

      # Perfoms a REST request based on the action hash (cf setup_actions)
      # ex : request (:user_retrieve, 'jsmith') sends a http GET www.google.com/a/feeds/domain/user/2.0/jsmith
      # returns  REXML Document
      def request(action, value=nil, message=nil, headers=@headers)
         #param value : value to be concatenated to action path ex: GET host/path/value
         method = @actions[action][:method]
         value = '' if !value
         path = @actions[action][:path]+value
         if Thread.current[:connection].nil?
           Thread.current[:connection] = Connection.new(@@google_host, @@google_port, @proxy, @proxy_port, @proxy_user, @proxy_passwd)
         end
         response = Thread.current[:connection].perform(method, path, message, headers)
         response_xml = parse_response(response)
         return response_xml
      end

      # parses xml response for an API error tag. If an error, constructs and raises a GDataError.
      def parse_response(response)
        if response.code == "503"
          gdata_error = GDataError.new
          gdata_error.code = "503"
          gdata_error.input = "-"
          gdata_error.reason = "Apps API invoked too rapidly."
          msg = "error code : "+gdata_error.code+", invalid input : "+gdata_error.input+", reason : "+gdata_error.reason
          raise gdata_error, msg
        end          
        
        xml = Document.new(response.body)

        error = xml.elements["AppsForYourDomainErrors/error"]
        if error
          gdata_error = GDataError.new
          gdata_error.code = error.attributes["errorCode"]
          gdata_error.input = error.attributes["invalidInput"]
          gdata_error.reason = error.attributes["reason"]
          msg = "error code : "+gdata_error.code+", invalid input : "+gdata_error.input+", reason : "+gdata_error.reason
          raise gdata_error, msg
        end
        return xml
      end
   end
end
