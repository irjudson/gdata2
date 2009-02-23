require 'rexml/document'
include REXML

module GData #:nodoc:
   module Apps #:nodoc:
      class Email
         def initialize(apps)
           @apps = apps
           setup_actions()
         end

         def create_label(username, label)
         end

         def create_filter(username)
         end

         def create_send_as_alias(username, name, address, reply_to=nil, make_default=false)
         end
         
         def set_webclip(username, enabled)
           msg = EmailMessage.new
           msg.about_webclip(enabled)
           response = @apps.request(:set_webclip, username, msg.to_s)
         end
         
         # action must be one of KEEP, ARCHIVE or DELETE
         def update_forward(username, forward_to, action="KEEP", enable=true)
         end
         
         # enable_for must be one of ALL_MAIL or MAIL_FROM_NOW_ON
         # action must be one of KEEP, ARCHIVE or DELETE
         def update_pop(username, enable=true, enable_for="ALL_MAIL", action="KEEP")
         end
         
         def update_imap(username, enable=true)
         end
         
         def update_vacation_settings(username, enable=false, subject="On Vacation", message="I'm off campus.", contacts_only=true)
         end
         
         def update_signature(username, sig="")
         end
         
         def update_language(username, lang="en-US")
         end
         
         def update_general_settings(username, page_size="50", shortcuts=true, arrows=true, snippets=true, unicode=true)
         end
         
         # private methods
         private #:nodoc:

         # Associates methods, http verbs and URL for REST access
         def setup_actions
            domain = @apps.domain
            path_base = '/a/feeds/emailsettings/2.0/'+domain+'/'
  
            @apps.register_action(:create_label, {:method => 'POST', :path => path_base })
            @apps.register_action(:create_filter, { :method => 'POST', :path => path_base })
            @apps.register_action(:create_send_as, { :method => 'POST', :path => path_base })
            @apps.register_action(:set_webclip, { :method => 'PUT', :path => path_base })
            @apps.register_action(:set_forward, { :method => 'PUT', :path => path_base +'/' })
            @apps.register_action(:set_pop, { :method => 'PUT', :path => path_base })
            @apps.register_action(:set_imap, { :method => 'PUT', :path =>path_base })
            @apps.register_action(:set_vacation, { :method => 'PUT', :path =>path_base })
            @apps.register_action(:set_signature, { :method => 'PUT', :path =>path_base })
            @apps.register_action(:set_language, { :method => 'PUT', :path =>path_base })
            @apps.register_action(:set_general, { :method => 'PUT', :path =>path_base })
            
            # special action "next" for linked feed results. :path will be affected with URL received in a link tag.
            @apps.register_action(:next,  {:method => 'GET', :path =>nil })
         end
      end

      class EmailMessage < RequestMessage #:nodoc:
         # creates the object and initiates the construction
         def initialize
            super 
         end

         def about_webclip(true_false)
            self.elements["atom:entry"].add_element "apps:property", {"name" => "enable", "value" => true_false.to_s}
         end
      end
   end
end
