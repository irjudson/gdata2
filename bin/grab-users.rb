#!/usr/bin/env ruby
#
#
ipath = File.expand_path(File.dirname(__FILE__))+'/../lib'
$:.unshift(ipath) unless $:.include?(ipath)

require 'rubygems'
require 'sqlite3'
require 'net/ldap'
require 'optparse'

require 'gdata'
require 'gdata/apps'
require 'timestamp'
require 'statedb'

$options = OpenStruct.new
$source = nil
$count = 0
$config = Hash.new

# Parse email address out of ldap entry
def get_mail(entry)
  entry['mail'].each do |addr|
   addr.downcase!

   if addr.nil? || addr.split("@")[1] == "myportal.montana.edu"
     return nil
   else
     return addr
   end
  end
end

# Parse NetID and UID from uid attributes
def parse_uids(uid_array, dn)
   uid_dn = dn.split(',')[0].split('=')[1]
   uid_alias = nil
   uid_array.each do |uid|
      if uid.match(uid_dn)
         uid_dn = uid
      else
         uid_alias = uid
      end
   end

   if uid_alias.nil?
      uid_alias = uid_dn
   end
   return uid_dn, uid_alias
end

# Parse commandline options
OptionParser.new do |opts|
   $options.verbose = false
   $options.config = 'config.yml'
   $options.reset = false
   $options.operator = ">="

   opts.banner = "Usage: sync-apps.rb [options]"

   opts.on("-r", "--reset", "Reset state for synchronization.") do |o|
      $options.reset = true
      $options.operator = "<="
   end

   opts.on("-c", "--config [FILE]", "Specify a config file.") do |o|
      $options.config = o.to_s
   end

   opts.on("-v", "--verbose", "Operate verbosely.") do |o|
      $options.verbose = true
   end

   opts.on_tail("--version", "Show version") do
      puts OptionParser::Version.join('.')
   end
end.parse!

# Load configuration file
$config = YAML.load_file($options.config)

# Create a source object to pull data from
if $config["source"]["type"] == "ldap"
   args = {
      :host => $config["source"]["host"],
      :port => $config["source"]["port"],
      :auth => {
         :method => :simple,
         :username => $config["source"]["user"],
         :password => $config["source"]["password"]
      }
   }

   if $config["source"]["port"].to_i == 636
      args[:encryption] = :simple_tls
   end

   $source = Net::LDAP.new args
end

# Create a local state store for keeping track of things between runs
state_db = State.new($config["state"]["file"])

state_db.reset_source if $options.reset
state_db.init_source if $options.reset


# Get the right timestamp to compare against for retrieving users from source data
ts = state_db.timestamp
if $options.reset || ts.nil?
   ts = Time.now.gmtime.strftime("%Y%m%d%H%M00Z")
end

# Pull attributes from the directory for users that have been modified since last run
#
# Get attributes we care about
attributes = $config["attributes"].values
admin_filter = ""
if $config['source'].has_key?('admins')
  $config['source']['admins'].each do |n|
    admin_filter += "(uid=#{n})"
  end
end

# Deal with Administrative Users & Extra Users
attributes = $config["attributes"].values
extra_filter = ""
if $config['source'].has_key?('extras')
  $config['source']['extras'].each do |n|
    extra_filter += "(uid=#{n})"
  end
end

# Build the ldap filter & grab the users
filter_string = $config['source']['filter']
if ! extra_filter.empty?
  filter_string = "(|#{filter_string}#{extra_filter})"
end
if ! admin_filter.empty?
  filter_string = "#{filter_string[0,filter_string.length-1]}#{admin_filter})"
end
filter_string = "(&(modifyTimestamp#{$options.operator}#{ts})#{filter_string})"
puts "Filter String: #{filter_string}" if $options.verbose
filter = Net::LDAP::Filter.construct(filter_string)
accounts = $source.search(:base => $config["source"]["base"], :filter => filter, :attributes => attributes)

puts "There are #{accounts.length} users in the source directory."
puts "There are #{state_db.count_users} users in the state database."

accounts.each do |entry|
   puts "DN: #{entry.dn}, TS: #{entry.modifyTimestamp}" if $options.verbose
   if state_db.check(entry.uniqueIdentifier, entry.modifyTimestamp)
     netid, user = parse_uids(entry.uid, entry.dn)
     state_db.update(entry, netid, user, get_mail(entry))
   end
end

state_db.close
