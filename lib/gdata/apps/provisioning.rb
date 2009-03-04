$:.unshift(File.expand_path(File.dirname(__FILE__))) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'messages'

module GData #:nodoc:
   module Apps #:nodoc:
      # =Administrative object for accessing your domain
      # Examples
      #
      #       adminuser = "root@mydomain.com"
      #       password  = "PaSsWo4d!"
      #       gapp = GApps.new('root@mydomain.com','PaSsWoRd')
      #       myapps = Provisioning.new(gapp)
      #       (see examples in  ProvisioningApi.new documentation for handling proxies)
      #
      #       new_user = myapps.create_user("jsmith", "john", "smith", "secret", nil, "2048")
      #       puts new_user.family_name
      #       puts new_user.given_name
      #
      # Want to update a user ?
      #
      #       user = myapps.retrieve_user('jsmith')
      #       user_updated = myapps.update_user(user.username, user.given_name, user.family_name, nil, nil, "true")
      #
      # Want to add an alias or nickname ?
      #
      #       new_nickname = myapps.create_nickname("jsmith", "john.smith")
      #
      # Want to handle errors ?
      #
      #       begin
      #               user = myapps.retrieve_user('noone')
      #               puts "givenName : "+user.given_name, "familyName : "+user.family_name, "username : "+user.username"
      #               puts "admin ? : "+user.admin
      #       rescue GDataError => e
      #               puts "errorcode = " +e.code, "input : "+e.input, "reason : "+e.reason
      #       end
      #
      # Group ?
      #
      #       new_list = myapps.create_group("sale-dep")
      #       new_address = myapps.add_to_group("sale-dep", "bibi@ruby-forge.org")
      #

      class Provisioning

         @@google_host = 'apps-apis.google.com'

         # Creates a new Provisioning object
         #
         #  apps:  Google Apps Object (GData::GApps)
         #
         #
         # Examples :
         #       standard : no proxy
         #       gapp = GApps.new('root@mydomain.com','PaSsWoRd')
         #       myapps = Provisioning.new(gapp)
         #       proxy :
         #       gapp = GApps.new('root@mydomain.com','PaSsWoRd','domain.proxy.com',8080)
         #       myapps = Provisioning.new(gapp)
         #       authenticated proxy :
         #       gapp = GApps.new('root@mydomain.com','PaSsWoRd','domain.proxy.com',8080,'foo','bAr')
         #       myapps = ProvisioningApi.new(gapp)
         #
         def initialize(apps)
           @apps = apps
           setup_actions()
         end

         # Creates an account in your domain, returns a UserEntry instance
         #       params :
         #                       username, given_name, family_name and password are required
         #                       passwd_hash_function (optional) : nil (default) or "SHA-1"
         #                       quota (optional) : nil (default) or integer for limit in MB
         #       ex :
         #                       gapp = GApps.new('root@mydomain.com','PaSsWoRd')
         #                       myapps = ProvisioningApi.new(gapp)
         #                       user = myapps.create('jsmith', 'John', 'Smith', 'p455wD')
         #
         # By default, a new user must change his password at first login. Please use update_user if you want to change this just after the creation.
         def create_user(username, given_name, family_name, password, passwd_hash_function=nil, quota=nil)
            msg = ProvisioningMessage.new
            msg.about_login(username,password,passwd_hash_function,"false","false", "true")
            msg.about_name(family_name, given_name)
            msg.about_quota(quota.to_s) if quota
            response  = @apps.request(:user_create,nil, msg.to_s)
            #user_entry = UserEntry.new(response.elements["entry"])
         end


         # Returns a UserEntry instance from a username
         #       ex :
         #                       gapp = GApps.new('root@mydomain.com','PaSsWoRd')
         #                       myapps = ProvisioningApi.new(gapp)
         #                       user = myapps.retrieve_user('jsmith')
         #                       puts "givenName : "+user.given_name
         #                       puts "familyName : "+user.family_name
         def retrieve_user(username)
            xml_response = @apps.request(:user_retrieve, username)
            user_entry = UserEntry.new(xml_response.elements["entry"])
         end

         # Returns a UserEntry array populated with all the users in the domain. May take a while depending on the number of users in your domain.
         #       ex :
         #                       gapp = GApps.new('root@mydomain.com','PaSsWoRd')
         #                       myapps = ProvisioningApi.new(gapp)
         #                       list= myapps.retrieve_all_users
         #                       list.each{ |user| puts user.username}
         #                       puts 'nb users : ',list.size
         def retrieve_all_users
            response = @apps.request(:user_retrieve_all)
            user_feed = Feed.new(response.elements["feed"],  UserEntry)
            user_feed = add_next_feeds(user_feed, response, UserEntry)
         end

         # Returns a UserEntry array populated with 100 users, starting from a username
         #       ex :
         #                       gapp = GApps.new('root@mydomain.com','PaSsWoRd')
         #                       myapps = ProvisioningApi.new(gapp)
         #                       list= myapps.retrieve_page_of_users("jsmtih")
         #                       list.each{ |user| puts user.username}
         def retrieve_page_of_users(start_username)
            param='?startUsername='+start_username
            response = @apps.request(:user_retrieve_all,param)
            user_feed = Feed.new(response.elements["feed"],  UserEntry)
         end

         # Updates an account in your domain, returns a UserEntry instance
         #       params :
         #                       username is required and can't be updated.
         #                       given_name and family_name are required, may be updated.
         #                       if set to nil, every other parameter won't update the attribute.
         #                               passwd_hash_function :  string "SHA-1" or nil (default)
         #                               admin :  string "true" or string "false" or nil (no boolean : true or false).
         #                               suspended :  string "true" or string "false" or nil (no boolean : true or false)
         #                               change_passwd :  string "true" or string "false" or nil (no boolean : true or false)
         #                               quota : limit en MB, ex :  string "2048"
         #               ex :
         #                       gapp = GApps.new('root@mydomain.com','PaSsWoRd')
         #                       myapps = ProvisioningApi.new(gapp)
         #                       user = myapps.update('jsmith', 'John', 'Smith', nil, nil, "true", nil, "true", nil)
         #                       puts user.admin         => "true"
         def update_user(username, given_name, family_name, password=nil, passwd_hash_function=nil, admin=nil, suspended=nil, changepasswd=nil, quota=nil)
            msg = ProvisioningMessage.new
            msg.about_login(username,password,passwd_hash_function,admin,suspended, changepasswd)
            msg.about_name(family_name, given_name)
            msg.about_quota(quota) if quota
            response  = @apps.request(:user_update,username, msg.to_s)
            #user_entry = UserEntry.new(response.elements["entry"])
         end

         # Deletes an account in your domain
         #               ex :
         #                       gapp = GApps.new('root@mydomain.com','PaSsWoRd')
         #                       myapps = ProvisioningApi.new(gapp)
         #                       myapps.delete('jsmith')
         def delete_user(username)
            response  = @apps.request(:user_delete,username)
         end

         # Creates a nickname for the username in your domain and returns a NicknameEntry instance
         #               gapp = GApps.new('root@mydomain.com','PaSsWoRd')
         #               myapps = ProvisioningApi.new(gapp)
         #               mynewnick = myapps.create_nickname('jsmith', 'john.smith')
         def create_nickname(username, nickname)
            msg = ProvisioningMessage.new
            msg.about_login(username)
            msg.about_nickname(nickname)
            response  = @apps.request(:nickname_create,nil, msg.to_s)
            #nickname_entry = NicknameEntry.new(response.elements["entry"])
         end

         # Returns a NicknameEntry instance from a nickname
         #       ex :
         #                       gapp = GApps.new('root@mydomain.com','PaSsWoRd')
         #                       myapps = ProvisioningApi.new(gapp)
         #                       nickname = myapps.retrieve_nickname('jsmith')
         #                       puts "login : "+nickname.login
         def retrieve_nickname(nickname)
            xml_response = @apps.request(:nickname_retrieve, nickname)
            nickname_entry = NicknameEntry.new(xml_response.elements["entry"])
         end

         # Returns a NicknameEntry array from a username
         #       ex : lists jsmith's nicknames
         #               gapp = GApps.new('root@mydomain.com','PaSsWoRd')
         #               myapps = ProvisioningApi.new(gapp)
         #               mynicks = myapps.retrieve('jsmith')
         #               mynicks.each {|nick| puts nick.nickname }
         def retrieve_nicknames(username)
            xml_response = @apps.request(:nickname_retrieve_all_for_user, username, @headers)
            nicknames_feed = Feed.new(xml_response.elements["feed"],  NicknameEntry)
            nicknames_feed = add_next_feeds(nicknames_feed, xml_response, NicknameEntry)
         end

         # Returns a NicknameEntry array for the whole domain. May take a while depending on the number of users in your domain.
         #       gapp = GApps.new('root@mydomain.com','PaSsWoRd')
         #       myapps = ProvisioningApi.new(gapp)
         #       allnicks = myapps.retrieve_all_nicknames
         #       allnicks.each {|nick| puts nick.nickname }
         def retrieve_all_nicknames
            xml_response = @apps.request(:nickname_retrieve_all_in_domain, nil, @headers)
            nicknames_feed = Feed.new(xml_response.elements["feed"],  NicknameEntry)
            nicknames_feed = add_next_feeds(nicknames_feed, xml_response, NicknameEntry)
         end

         # Deletes the nickname  in your domain
         #               gapp = GApps.new('root@mydomain.com','PaSsWoRd')
         #               myapps = ProvisioningApi.new(gapp)
         #               myapps.delete_nickname('john.smith')
         def delete_nickname(nickname)
            response  = @apps.request(:nickname_delete,nickname)
         end

         # Returns a NicknameEntry array populated with 100 nicknames, starting from a nickname
         #       ex :
         #              gapp = GApps.new('root@mydomain.com','PaSsWoRd')
         #              myapps = ProvisioningApi.new(gapp)
         #              list= myapps.retrieve_page_of_nicknames("joe")
         #              list.each{ |nick| puts nick.login}
         def retrieve_page_of_nicknames(start_nickname)
            param='?startNickname='+start_nickname
            xml_response = @apps.request(:nickname_retrieve_all_in_domain, param, @headers)
            nicknames_feed = Feed.new(xml_response.elements["feed"],  NicknameEntry)
         end

         def create_group
           raise NotImplementedError
         end
         
         def update_group
           raise NotImplementedError
         end
         
         def retrieve_group
           raise NotImplementedError
         end
         
         def delete_group
           raise NotImplementedError
         end
         
         def add_member_to_group
           raise NotImplementedError
         end
         
         def retrieve_members_of_group
           raise NotImplementedError
         end
         
         def remove_member_from_group
           raise NotImplementedError
         end
         
         def add_owner_to_group
           raise NotImplementedError
         end
         
         def retrieve_owner_of_group
           raise NotImplementedError
         end
         
         def remove_owner_from_group
           raise NotImplementedError
         end
         
         # private methods
         private #:nodoc:

         # Associates methods, http verbs and URL for REST access
         def setup_actions
            domain = @apps.domain
            path_user = '/a/feeds/'+domain+'/user/2.0'
            path_nickname = '/a/feeds/'+domain+'/nickname/2.0'
            path_email_list = '/a/feeds/'+domain+'/emailList/2.0'
            path_group = '/a/feeds/group/2.0/'+domain
            
            @apps.register_action(:domain_login, {:method => 'POST', :path => '/accounts/ClientLogin' })
            @apps.register_action(:user_create, { :method => 'POST', :path => path_user })
            @apps.register_action(:user_retrieve, { :method => 'GET', :path => path_user+'/' })
            @apps.register_action(:user_retrieve_all, { :method => 'GET', :path => path_user })
            @apps.register_action(:user_update, { :method => 'PUT', :path => path_user +'/' })
            @apps.register_action(:user_delete, { :method => 'DELETE', :path => path_user +'/' })
            @apps.register_action(:nickname_create, { :method => 'POST', :path =>path_nickname })
            @apps.register_action(:nickname_retrieve, { :method => 'GET', :path =>path_nickname+'/' })
            @apps.register_action(:nickname_retrieve_all_for_user, { :method => 'GET', :path =>path_nickname+'?username=' })
            @apps.register_action(:nickname_retrieve_all_in_domain, { :method => 'GET', :path =>path_nickname })
            @apps.register_action(:nickname_delete, { :method => 'DELETE', :path =>path_nickname+'/' })
            @apps.register_action(:group_create, { :method => 'POST', :path => path_group })
            @apps.register_action(:group_update, { :method => 'PUT', :path => path_group })
            @apps.register_action(:group_retrieve, { :method => 'GET', :path => path_group })
            @apps.register_action(:group_delete, { :method => 'DELETE', :path => path_group })
            
            # special action "next" for linked feed results. :path will be affected with URL received in a link tag.
            @apps.register_action(:next,  {:method => 'GET', :path =>nil })
         end

         # Completes the feed by following et requesting the URL links
         def add_next_feeds(current_feed, xml_content,element_class)
            xml_content.elements.each("feed/link") {|link|
               if link.attributes["rel"] == "next"
                  @action[:next] = {:method => 'GET', :path=> link.attributes["href"]}
                  next_response = @apps.request(:next)
                  current_feed.concat(Feed.new(next_response.elements["feed"], element_class))
                  current_feed = add_next_feeds(current_feed, next_response, element_class)
               end
            }
            return current_feed
         end
      end


      # UserEntry object.
      #
      # Handles API responses relative to a user
      #
      # Attributes :
      #       username : string
      #       given_name : string
      #       family_name : string
      #       suspended : string "true" or string "false"
      #       ip_whitelisted : string "true" or string "false"
      #       admin : string "true" or string "false"
      #       change_password_at_next_login : string "true" or string "false"
      #       agreed_to_terms : string "true" or string "false"
      #       quota_limit : string (value in MB)
      class UserEntry
         attr_reader :given_name, :family_name, :username, :suspended, :ip_whitelisted, :admin, :change_password_at_next_login, :agreed_to_terms, :quota_limit

         # UserEntry constructor. Needs a REXML::Element <entry> as parameter
         def initialize(entry) #:nodoc:
            @family_name = entry.elements["apps:name"].attributes["familyName"]
            @given_name = entry.elements["apps:name"].attributes["givenName"]
            @username = entry.elements["apps:login"].attributes["userName"]
            @suspended = entry.elements["apps:login"].attributes["suspended"]
            @ip_whitelisted = entry.elements["apps:login"].attributes["ipWhitelisted"]
            @admin = entry.elements["apps:login"].attributes["admin"]
            @change_password_at_next_login = entry.elements["apps:login"].attributes["changePasswordAtNextLogin"]
            @agreed_to_terms = entry.elements["apps:login"].attributes["agreedToTerms"]
            @quota_limit = entry.elements["apps:quota"].attributes["limit"]
         end
      end

      # NicknameEntry object.
      #
      # Handles API responses relative to a nickname
      #
      # Attributes :
      #       login : string
      #       nickname : string
      class NicknameEntry
         attr_reader :login, :nickname

         # NicknameEntry constructor. Needs a REXML::Element <entry> as parameter
         def initialize(entry) #:nodoc:
            @login = entry.elements["apps:login"].attributes["userName"]
            if entry.elements["apps:nickname"].nil?
              # IRJ Some call is failing 10 minutes into a run, I'll debug 
              @nickname = nil
            else
              @nickname = entry.elements["apps:nickname"].attributes["name"]
            end
         end
      end

      # UserFeed object : Array populated with Element_class objects (UserEntry, NicknameEntry, EmailListEntry or EmailListRecipientEntry)
      class Feed < Array #:nodoc:

         # UserFeed constructor. Populates an array with Element_class objects. Each object is an xml <entry> parsed from the REXML::Element <feed>.
         # Ex : user_feed = Feed.new(xml_feed, UserEntry)
         #               nickname_feed = Feed.new(xml_feed, NicknameEntry)
         def initialize(xml_feed, element_class)
            xml_feed.elements.each("entry"){ |entry| self << element_class.new(entry) }
         end
      end

      class ProvisioningMessage < GData::RequestMessage #:nodoc:
        def initialize
          super
          self.elements["atom:entry"].add_element "atom:category", {"scheme" => "http://schemas.google.com/g/2005#kind"}
        end

        # adds <apps:login> element in the message body.
        # warning :  if valued admin, suspended, or change_passwd_at_next_login must be the STRINGS "true" or "false", not the boolean true or false
        # when needed to construct the message, should always been used before other "about_" methods so that the category tag can be overwritten
        # only values permitted for hash_function_function_name : "SHA-1" or nil
        def about_login(user_name, passwd=nil, hash_function_name=nil, admin=nil, suspended=nil, change_passwd_at_next_login=nil)
           self.elements["atom:entry/atom:category"].add_attribute("term", "http://schemas.google.com/apps/2006#user")
           self.elements["atom:entry"].add_element "apps:login", {"userName" => user_name }
           self.elements["atom:entry/apps:login"].add_attribute("password", passwd) if not passwd.nil?
           self.elements["atom:entry/apps:login"].add_attribute("hashFunctionName", hash_function_name) if not hash_function_name.nil?
           self.elements["atom:entry/apps:login"].add_attribute("admin", admin) if not admin.nil?
           self.elements["atom:entry/apps:login"].add_attribute("suspended", suspended) if not suspended.nil?
           self.elements["atom:entry/apps:login"].add_attribute("changePasswordAtNextLogin", change_passwd_at_next_login) if not change_passwd_at_next_login.nil?
           return self
        end

        # adds <apps:quota> in the message body.
        # limit in MB: integer
        def about_quota(limit)
           self.elements["atom:entry"].add_element "apps:quota", {"limit" => limit }
           return self
        end

        # adds <apps:name> in the message body.
        def about_name(family_name, given_name)
           self.elements["atom:entry"].add_element "apps:name", {"familyName" => family_name, "givenName" => given_name }
           return self
        end

        # adds <apps:nickname> in the message body.
        def about_nickname(name)
           self.elements["atom:entry/atom:category"].add_attribute("term", "http://schemas.google.com/apps/2006#nickname")
           self.elements["atom:entry"].add_element "apps:nickname", {"name" => name}
           return self
        end
      end
   end
end
