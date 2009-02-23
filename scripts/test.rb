#!/usr/bin/env ruby
#
#
$: << '../lib'

require 'yaml'
require 'gdata'
require 'gdata/apps'
require 'gdata/apps/provisioning'
require 'gdata/apps/email'

config = YAML.load_file("config.yml")

apps = GData::GApps.new(config["user"], config["password"])
prov = GData::Apps::Provisioning.new(apps)
mail = GData::Apps::Email.new(apps)

# t = prov.create_user("d2ltest", "D2LTest", "User", "d2ltest&pass")
# puts t
# n = prov.create_nickname("d2ltest", "0.d2ltest")
# puts n

prov.retrieve_all_users.each do |user|
  puts "User: #{ user.inspect }"
end

begin
  mail.set_webclip("d2ltest", false)
rescue GData::GDataError => e
  puts "errorcode = " +e.code, "input : "+e.input, "reason : "+e.reason
end
