#!/usr/bin/env ruby
#
# Name: GRAB-USERS.RB
# Purpose: Appears to grab myportal.yml and use the values in there to construct a query of 
#          the LDAP server for the people listed in the Source->admins and Source->extras 
#          sections of the .yml file. 
# Location: Roster:/home/academic/gdata2/bin
# Inputs: /home/academic/gdata2/bin/myportal.yml pass in by commandline parameter in the Academic
#         users crontab on Roster.  
# Outputs: This updates the state database that is used by bin/gapps-provision to update google apps users.
# Called From: Academic users crontab on Roster
# Calls to: statedb.rb which appears to be a custom interface to the Google Apps API utilities
# Notes: 
#
# The libraries are assumed to be in a "../lib" relative to the directory
# this was called from.  Get the relative directory this was called from
# and add the relative path to the library directory to $LOAD_PATH ($:) so
# the program can find it's libraries.
#
include_path = File.expand_path(File.dirname(__FILE__))+'/../lib'
$:.unshift(include_path) unless $:.include?(include_path)

require 'rubygems'
require 'sqlite3'
require 'net/ldap'
require 'optparse'

require 'gdata'
require 'gdata/apps'
require 'timestamp'

#
# 6/4/10: statedb appears to be a custom interface to the GApps API routines.
#         Need to go through statedb and document that next - mb
# 
# 6/11/10: 
#         Statedb is a local sqlite database use to cache values needed in each run of the 
#         provisioning. It is primarily used to avoid reprovisioning people, since a 
#         provisioned flag is not able to be written back into ldap (that isn't necessarily 
#         where it should go anyway) - irj
#
require 'statedb'

#
# 6/7/10: Create an open data object called $options we can stuff useful
#         options in for later use. This supposedly needs "require 'ostruct'"
#         but I don't see it anywhere.  How is this working - or is it? -mb
# 
# 6/10/10: ostruct is required in 'net/ldap' so it's already loaded by a previous require. -- IRJ
#
$options = OpenStruct.new
$source = nil
$count = 0

#
# 6/8/10: Create a hash table, a collection of key-value pairs similar to an array
#         but indexing is done via arbitrary keys rather than integer indexes - mb
#
$config = Hash.new

##
# This pulls the email address out of ldap entry
# 
# @param [Net::LDAP::Entry] entry The LDAP entry to be processed.
#
# @return [String] The email address in the LDAP entry.
# 
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

##
# This extracts the netid and the first first.last alias in ldap
# TODO: This should probably check all first.last aliases, since we accumulate them in LDAP
# 
# @param [Array of Strings] uid_array an array of the uid attributes in ldap
# @param [String] dn the distinguishedName attribute from ldap
# 
# @return [String, String] distinguishedName (NetID) and first first.last alias
# 
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
#
# 6/4/10: OptionParser is a class defined in /opt/jruby/lib/ruby/1.8/optparse.rb I think and
#         included in the "require 'optparse'" statement above. This is a command-line
#         option analysis class.  More advanced and easier to use than GetoptLong. 
#
#         Check for command-line options and handle them - mb
#
# 6/10/10: This also stores command line options in the $options object for use later. -- IRJ
#
OptionParser.new do |opts|
   $options.verbose = false
   $options.config = 'config.yml'
   $options.reset = false
   $options.operator = ">="

   opts.banner = "Usage: grab-users.rb [options]"

   opts.on("-r", "--reset", "Reset state for synchronization.") do |o|
      $options.reset = true
      $options.operator = "<="
   end

#
# 6/8/10: Store the configuration file specified on the command line in $options.config - mb
#
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

#
# 6/4/10: Load the configuration file.  The default is called "config.yml" but this
#         program is called from academic users crontab and passed
#         "-c /home/academic/gdata2/bin/myportal.yml so we'll open myportal.yml - mb
#
$config = YAML.load_file($options.config)

# Create a source object to pull data from
#
# 6/8/10: The myportal.yml file has the structure we can pull from below:
#    apps:
#       domain: myportal.montana.edu
#    source:
#       type: ldap
#       host: roster.msu.montana.edu
#       port: 636
#         etc.
# Now that we've loaded the configuration file into the $config structure
# we can pull the individual values from the YAML configuration with
# $config["apps"]["domain"] or $config["source"]["host"] as shown below.
#
# Set up a hash table "args" with values we want from the configuration file.
# Specifically, get the host name, port used, authorization method, username
# and password. - mb
#
#
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

#
# 6/9/10:  Create a new NET::LDAP object and open a connection to the host we just stuffed
#          into the args hash. - mb
#
   $source = Net::LDAP.new args
end

# Create a local state store for keeping track of things between runs
#
# 6/8/10 - The State class is defined in the "statedb" require at the top. This
#          opens the database extracted from the configuration file.  In this case
#          /home/academic/rosterdb.sqlite - mb
#
state_db = State.new($config["state"]["file"])

#
# 6/8/10: If the user selected "-r" for reset on the command line drop the "user"
#         and "updates" tables from the database.  See reset_source in statedb.rb - mb
#
state_db.reset_source if $options.reset

#
# 6/8/10:  If the user selected "-r" for reset on the command line, recreate the
#          "user" and "updates" tables in the database.  See init_source in statedb.rb - mb
#
state_db.init_source if $options.reset

# Get the right timestamp to compare against for retrieving users from source data
#
# 6/8/10: Get the right timestamp and format properly to compare against time format in rosterdb.sqlite
#         for retrieving users. -mb
#
ts = state_db.timestamp
if $options.reset || ts.nil?
   ts = Time.now.gmtime.strftime("%Y%m%d%H%M00Z")
end

# Pull attributes from the directory for users that have been modified since last run
# Get only attributes we care about
#
# 6/9/10: I think attributes gets all the values in the "attributes" section of myportal.yml - mb
# 6/10/10: Yes, this is specifying a subset of attributes to get out of LDAP rather than all of them. -- IRJ
attributes = $config["attributes"].values

#
# 6/9/10: Build an administrator filter.  myportal.yml has a source section and an admin
#         section within that.  Pull all the admins out and make a filter for them. At the
#         moment that's Ivan and Tyghe.  The filter looks something like this when done:
#                               (uid=ivan.judson)(uid=tyghe.vallard)
#         Left original comments above in case they offer something I don't understand yet. Error
#         checking includeis making sure the .yml file has a "admin" section. - mb
#
admin_filter = ""
if $config['source'].has_key?('admins')
  $config['source']['admins'].each do |n|
    admin_filter += "(uid=#{n})"
  end
end

# Deal with Administrative Users & Extra Users
#
# 6/9/10: Grab everyone from the "extras" section under "source" in myportal.yml. This would be
#         a lot of other people such as me, Hall, Hitch, Eck, Burk, etc.  Does not include the
#         people in the admin section. The filter looks something like this when done: - mb
#                  (uid=samuel.taylor1)(uid=cherie.eck)(uid=charles.hatfield)
#                  (uid=michael.hall16)(uid=martin.bourque)(uid=leo.bratsky)
#                  (uid=robert.underkofler)
#         Again, error checking includes verifying the .yml file has an "extras" section under "source"
#         Setting attributes a second time for some reason - mb
#
extra_filter = ""
if $config['source'].has_key?('extras')
  $config['source']['extras'].each do |n|
    extra_filter += "(uid=#{n})"
  end
end

# Build the ldap filter & grab the users
#
# 6/9/10: filter_string starts off as the filter listed in "filter" of the source section in myportal.yml:
#           (montanaEduPersonClassicRoles=*_s*)(montanaEduPersonClassicRoles=*_e*)
#
filter_string = $config['source']['filter']

#
# 6/9/10: Append the extra_filter built above if it's not empty - mb
#
if ! extra_filter.empty?
  filter_string = "(|#{filter_string}#{extra_filter})"
end

#
# 6/9/10: Append the admin_filter if it's not empty - mb
#
if ! admin_filter.empty?
  filter_string = "#{filter_string[0,filter_string.length-1]}#{admin_filter})"
end

#
# 6/9/10: Prepends something similiar to "(&(modifyTimestamp20100609172200Z)" to filter_string.
#         Not sure how the filters work just yet - mb
# 6/10/10: This constructs a filter that is dependant on command line options. If it's being 
#          run normally, the operator will be such that you only get datay for entries 
#          modified since the last this was run. otherwise, get all the data because
#          a reset was done. -- IRJ
filter_string = "(&(modifyTimestamp#{$options.operator}#{ts})#{filter_string})"
puts "Filter String: #{filter_string}" if $options.verbose

#
# 6/9/10: Still can't find any documentation on this.  It appears to convert filter_string built
#         above to a different format fo the LDAP search but I have no idea what that format is - mb
#
# 6/10/10: This converts the filter into a LDAP compatible filter, using the Net::LDAP::Filter object. -- IRJ
filter = Net::LDAP::Filter.construct(filter_string)
accounts = $source.search(:base => $config["source"]["base"], :filter => filter, :attributes => attributes)

#
# 6/9/10: Dump some hopefully useful information - mb
#
#
puts "There are #{accounts.length} users in the source directory."
puts "There are #{state_db.count_users} users in the state database."

# For each account we've retrieved from LDAP
accounts.each do |entry|
  # Print the distinguishedName and Timestamp
  puts "DN: #{entry.dn}, TS: #{entry.modifyTimestamp}" if $options.verbose
  # Check the state_db (state database) to see if the entry needs to be updated.
  if state_db.check(entry.uniqueIdentifier, entry.modifyTimestamp)
    # Extract the netid and first.last from the LDAP Entry
    netid, user = parse_uids(entry.uid, entry.dn)
    # Update the user information in the state database, so that the next process in the 
    # workflow can extract it and make the Google Changes that need to be made.
    state_db.update(entry, netid, user, get_mail(entry))
  end
end

# Cleanly close the state_db so that it doesn't get corrupted.
state_db.close
