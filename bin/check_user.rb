#!/usr/bin/env ruby
#
#
$: << '../lib'

require 'rubygems'
require 'optparse'
require 'digest/sha1'
require 'ostruct'

require 'gdata'
require 'gdata/apps'

$options = OpenStruct.new

# Parse commandline options
OptionParser.new do |opts|
   $options.verbose = false
   $options.config = 'config.yml'
   $options.first = nil
   $options.last = nil
   $options.netid = nil
   $options.alias = nil

   opts.banner = "Usage: check_user.rb [options]"

   opts.on("-c", "--config [FILE]", "Specify a config file.") do |o|
      $options.config = o.to_s
   end

   opts.on("-v", "--verbose", "Operate verbosely.") do |o|
      $options.verbose = true
   end

  # opts.on("-f", "--first-name [FIRST_NAME]", "Find users with first name.") do |o|
  #    $options.first = o.to_s
  #  end
  #  
  #  opts.on("-l", "--last-name [LAST_NAME]", "FInd users with last name.") do |o|
  #    $options.last = o.to_s
  #  end
  #  
   opts.on("-n", "--netid [NETID]", "Find user with netid.") do |o|
     $options.netid = o.to_s
   end
  
   # opts.on("-a", "--alias [ALIAS]", "Find user with alias.") do |o|
   #   $options.alias = o.to_s
   # end

   opts.on_tail("--version", "Show version") do
      puts OptionParser::Version.join('-')
   end
end.parse!

# Load configuration file
config = YAML.load_file($options.config)

# Create the Google Apps user and objects
user = config["apps"]["user"]+"@"+config["apps"]["domain"]
puts "Creating Apps Account Endpoint for #{user}." if $options.verbose
apps = GData::GApps.new(user, config["apps"]["password"])

# Find the user
search_user = apps.provision.retrieve_user($options.netid) unless $options.netid.nil?
nicknames = apps.provision.retrieve_nicknames($options.netid) unless $options.netid.nil?

puts search_user.to_s
nicknames.each do |nick|
  puts nick.to_s
end