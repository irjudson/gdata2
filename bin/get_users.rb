#!/usr/bin/env ruby
#
#
ipath = File.expand_path(File.dirname(__FILE__))+'/../lib'
$:.unshift(ipath) unless $:.include?(ipath)
#puts "IP: #{ipath}"
#$: << '../lib'

require 'rubygems'
require 'optparse'
require 'digest/sha1'
require 'ostruct'

require 'gdata'
require 'gdata/apps'

$options = OpenStruct.new
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

# Parse commandline options
OptionParser.new do |opts|
  $options.verbose = false
  $options.config = 'config.yml'
  $options.netid = nil
  $options.all = false

  opts.banner = "Usage: check_user.rb [options]"

  opts.on("-c", "--config [FILE]", "Specify a config file.") do |o|
    $options.config = o.to_s
  end

  opts.on("-v", "--verbose", "Operate verbosely.") do |o|
    $options.verbose = true
  end

  opts.on("-n", "--netid [NETID]", "Find user with netid.") do |o|
    $options.netid = o.to_s
  end

  opts.on("-a", "--all-users", "Find all users.") do |o|
    $options.all = true
  end

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

if $options.all
  apps.provision.retrieve_all_users.each do |user|
    nicks = apps.provision.retrieve_nicknames(user.username)
    puts user.to_s
    nicks.each do |nick|
      puts nick.to_s
    end
  end
else
  # Find the user
  search_user = apps.provision.retrieve_user($options.netid) unless $options.netid.nil?
  nicknames = apps.provision.retrieve_nicknames($options.netid) unless $options.netid.nil?

  puts search_user.to_s
  nicknames.each do |nick|
    puts nick.to_s
  end
end
