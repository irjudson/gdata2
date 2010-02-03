#!/usr/bin/env ruby

require 'rubygems'
require 'sqlite3'
require 'net/ldap'
require 'optparse'

$options = OpenStruct.new
$source = nil
$count = 0
$config = Hash.new

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
   $options.user = "benjamin.livingood"
   $options.operator = ">="

   opts.banner = "Usage: sync-apps.rb [options]"
   
   opts.on("-u", "--user [NAME]", "uid first.laste") do |o|
      $options.user = o.to_s
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

#filter_string = "(&#{filter_string}(uid=#{$options.user})"
filter_string = "(uid=#{$options.user})"


puts "Filter String: #{filter_string}" if $options.verbose

filter = Net::LDAP::Filter.construct(filter_string)

accounts = $source.search(:base => $config["source"]["base"], :filter => filter, :attributes => attributes)

puts $options.user

##<Net::LDAP::Entry:0x3560b0 @myhash={:modifytimestamp=>["20090831200510Z"], :givenname=>["Benjamin"], :mail=>["icedrake@cs.montana.edu"], :sn=>["Livingood"], :montanaedupersonclassicroles=>["bz_em"], :uid=>["h47z861", "benjamin.livingood"], :createtimestamp=>["20090227010347Z"], :dn=>["uid=h47z861,ou=people,dc=montana,dc=edu"], :uniqueidentifier=>["h47z861"]}>

accounts.each do |entry|
	puts "#{entry[:montanaedupersonclassicroles]} | #{entry[:sn] }, #{entry[:givenname]}"
	puts entry[:mail]
  puts "---"*5	
end

