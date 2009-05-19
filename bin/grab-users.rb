#!/usr/bin/env ruby
#
#
ipath = File.expand_path(File.dirname(__FILE__))+'/../lib'
$:.unshift(ipath) unless $:.include?(ipath)
#puts "IP: #{ipath}"
#$: << '../lib'

require 'rubygems'
require 'sqlite3'
require 'net/ldap'
require 'optparse'
require 'digest/sha1'
require 'thread'
require 'timeout'
require 'faster_csv'

require 'gdata'
require 'gdata/apps'
require 'timestamp'

$options = OpenStruct.new
$source = nil
$count = 0
$config = Hash.new

class State
   attr_reader :timestamp

   def initialize(fn, timestamp="19700000000000Z")
      @timestamp = nil

      if !File.exists?(fn)
         needs_initialization = 1
      end

      puts "Creating new state database." if $options.verbose

      @db = SQLite3::Database.new(fn)

      if needs_initialization
         do_initialization
      else
         @db.execute("SELECT * FROM updates;") do |@timestamp|
         end
      end
         end

   def do_initialization
      puts "Initializing state database." if $options.verbose
      @db.execute("CREATE TABLE users (idx TEXT PRIMARY KEY, created TEXT, last_modified TEXT, roster_modified TEXT, netid TEXT, first TEXT, last TEXT, first_last TEXT, bz TEXT, bl TEXT, gf TEXT, hv TEXT, forward TEXT, google TEXT);")
      @db.execute("CREATE TABLE updates (ts TEXT);")
   end

   def reset
      puts "Resetting state database." if $options.verbose
      @db.execute("DELETE FROM users;")
      @timestamp = "19700000000000Z"
      update_timestamp
   end

   def show_users
      @db.execute("SELECT * FROM updates;") do |ts|
          puts "Last touched: #{ts}"
      end

      puts "Dumping users:"
      @db.execute("SELECT * FROM users;") do |user|
         puts user.join(", ")
      end
   end

   def update_timestamp
      @timestamp=Time.now.gmtime.strftime("%Y%m%d%H%M00Z")

      @db.execute("DELETE FROM updates;")
      @db.execute("INSERT INTO updates (ts) VALUES ('#{@timestamp}');")
   end

   def count_users
      result = 0
      @db.execute("SELECT count(*) FROM users;") do |result|
          return result
      end
   end

   def exists?(entry)
      @db.execute("SELECT last_modified FROM users WHERE idx='?'", entry) do |ts|
        puts "Exists: #{ts.inspect} #{ts.length}"
          if ts.length == 1
             return true
          elsif ts.length > 1
             puts "More than one user found for id #{entry}"
          else
             return false
          end
      end
   end

   def update(entry, ts=nil)
      ts ||= Time.now.gmtime.strftime("%Y%m%d%H%M00Z")
      username, uid_alias = parse_uids(entry.uid, entry.dn)
      forward = Array.new
      google = 0
      bz = 0
      bl = 0
      gf = 0
      hv = 0
      entry.montanaEduPersonClassicRoles.each do |role|
        case role[0..3]
          when "bz_s", "bz_w": (fwalias = "#{uid_alias}@msu.montana.edu") && bz = 1 && google = 1
          when "bl_s", "bl_w": (fwalias = "#{uid_alias}@student.msubillings.edu") && bl = 1 && google = 1
          when "gf_s", "gf_w": (fwalias = "#{uid_alias}@my.msugf.edu") && gf = 1 && google = 1
          when "hv_s", "hv_w": (fwalias = "#{uid_alias}@students.msun.edu") && hv = 1 && google = 1
          when "bz_e", "bl_e", "gf_e", "hv_e": (fwalias = get_mail(entry)) && google = 0
          else
            puts "Unknown role found! #{role[0..3]}" if options.verbose
        end
       if ! forward.include?(fwalias)
         forward.push(fwalias)
       end
      end
     if (($config.has_key?('admins') && $config['admins'].include?(uid_alias))         || ($config.has_key?('extras') && $config['extras'].include?(uid_alias)))
       google = 1
     end
      if entry.givenName.is_a?(Array)
        first_name = entry.givenName[0]
      else
        first_name = entry.givenName
      end
      if entry.sn.is_a?(Array)
        last_name = entry.sn[0]
      else
        last_name = entry.sn
      end
      first_name.gsub!('\'', '\\\'')
      last_name.gsub!('\'', '\\\'')

      if ! exists?(entry.uniqueIdentifier)
        begin
            puts "Inserting #{entry.dn} with TS: #{ts}" if $options.verbose
            puts "QUERY: "+"INSERT INTO users (idx, created, last_modified, roster_modified, netid, first, last, first_last, bz, bl, gf, hv, forward, google) VALUES ('#{entry.uniqueIdentifier}', '#{entry.createTimestamp}', '#{entry.modifyTimestamp}', '#{ts}', '#{username}', '#{first_name}', '#{last_name}', '#{uid_alias}', '#{bz}', '#{bl}', '#{gf}', '#{hv}', '#{forward.join(",")}', '#{google}')" if $options.verbose
            @db.execute("INSERT INTO users (idx, created, last_modified, roster_modified, netid, first, last, first_last, bz, bl, gf, hv, forward, google) VALUES ('#{entry.uniqueIdentifier}', '#{entry.createTimestamp}', '#{entry.modifyTimestamp}', '#{ts}', '#{username}', '#{first_name}', '#{last_name}', '#{uid_alias}', '#{bz}', '#{bl}', '#{gf}', '#{hv}', '#{forward.join(",")}', '#{google}')")
        rescue SQLite3::SQLException => e
            puts "Exception inserting data in db ", e
            puts "QUERY: "+"INSERT INTO users (idx, created, last_modified, roster_modified, netid, first, last, first_last, bz, bl, gf, hv, forward, google) VALUES ('#{entry.uniqueIdentifier}', '#{entry.createTimestamp}', '#{entry.modifyTimestamp}', '#{ts}', '#{username}', '#{first_name}', '#{last_name}', '#{uid_alias}', '#{bz}', '#{bl}', '#{gf}', '#{hv}', '#{forward.join(",")}', '#{google}')"
        end
      else
        begin
          puts "Updating #{entry.dn} with TS: #{ts}" if $options.verbose
          @db.execute("UPDATE users SET created = '#{entry.createTimestamp}', last_modified = '#{entry.modifyTimestamp}', roster_modified = '#{ts}', netid = '#{username}', first = '#{first_name}', last = '#{last_name}', first_last = '#{uid_alias}', bz = '#{bz}', bl = '#{bl}', gf = '#{gf}', hv = '#{hv}', forward = '#{forward.join(",")}', google = '#{google}' WHERE idx = '#{entry.uniqueIdentifier}'")
        rescue SQLite3::SQLException => e
          puts "Exception updating data in db ", e
          puts "QUERY: "+"UPDATE users SET last_modified = '#{ts}' WHERE idx = '#{entry}'"
        end
      end
    end

   def check(entry, source_stamp)
      source = Time.parse(source_stamp[0])
      @db.execute("SELECT roster_modified FROM users WHERE idx='#{entry}'") do |ts|
          now = Time.parse(ts.to_s)
          if now < source
             return true
          else
             return false
          end
      end
      return true
   end

   def close
     @db.close
   end
end

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

#
# Main Program
#

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
state_db.reset if $options.reset

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
#
# Deal with Administrative Users & Extra Users
attributes = $config["attributes"].values
extra_filter = ""
if $config['source'].has_key?('extras')
  $config['source']['extras'].each do |n|
    extra_filter += "(uid=#{n})"
  end
end
#
# Build the ldap filter & grab the users
#filter_string = "(&(modifyTimestamp#{$options.operator}#{ts})(|#{config['source']['filter']}#{admin_filter}#{extra_filter}))"
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

$output = nil
if not $options.output_file.nil?
   $output = FasterCSV.open($options.output_file, 'w')
   $output << ["username", "first name", "last name", "password"]
end

accounts.each do |entry|
   puts "DN: #{entry.dn}, TS: #{entry.modifyTimestamp}" if $options.verbose
   if state_db.check(entry.uniqueIdentifier, entry.modifyTimestamp)
     state_db.update(entry)
   end
end

# Update our local timestamp
state_db.update_timestamp if not $options.reset
state_db.close
