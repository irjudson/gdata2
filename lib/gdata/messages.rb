require 'rexml/document'
include REXML

module GData #:nodoc:
  class RequestMessage < Document #:nodoc:
     # Request message constructor.
     # parameter type : "user", "nickname" or "emailList"

     # creates the object and initiates the construction
     def initialize
        super '<?xml version="1.0" encoding="UTF-8"?>'
        self.add_element "atom:entry", {"xmlns:apps" => "http://schemas.google.com/apps/2006",
           "xmlns:gd" => "http://schemas.google.com/g/2005",
        "xmlns:atom" => "http://www.w3.org/2005/Atom"}
        self.elements["atom:entry"].add_element "atom:category", {"scheme" => "http://schemas.google.com/g/2005#kind"}
     end

     # adds <atom:id> element in the message body. Url is inserted as a text.
     def add_path(url)
        self.elements["atom:entry"].add_element "atom:id"
        self.elements["atom:entry/atom:id"].text = url
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

     # adds <gd:who> in the message body.
     def about_who(email)
        self.elements["atom:entry"].add_element "gd:who", {"email" => email }
        return self
     end
  end
end
