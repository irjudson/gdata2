#!/usr/bin/env ruby
$: << '../lib'

require 'benchmark'
require 'set'

require 'rubygems'
require 'sqlite3'
require 'optparse'
require 'thread'
require 'timeout'
require 'ostruct'

require 'gdata'
require 'gdata/apps'
require 'timestamp'
require 'statedb'

#---
#invocation
#    ruby gcreate.rb -c configfile -u uid
#  relies on the fact that you have a user that has their affiliations
#  set and that the config file has the proper listing of db keys
#  generally this is the gapps-provision yml file
#  you might also have to have the user have an updated timestamp in
# last modified. not sure.


$options = OpenStruct.new
$queue = Array.new
$sync = Mutex.new
$source = nil
$count = 0
$forward_domains = Hash.new

# --------------------------------------------------
#-- overloading Array

class Array
  def / len
    a = []
    each_with_index do |x,i|
      a << [] if i % len == 0
      a.last << x
    end
    a
  end
end #allows for Array / 3 and get back chunks of 3
# --------------------------------------------------

# --------------------------------------------------
# functions

#print the list num wide

def pretty_print(list,num)
  a = list.dup #otherwise slice! will eat your incoming list
  while a.length > 0
    STDERR.puts a.slice!(0,num).join(" ")
  end
end

def random_password(size = 12)
   chars = (('a'..'z').to_a + ('0'..'9').to_a) - %w(i o 0 1 l 0)
   password = (1..size).collect{|a| chars[rand(chars.size)] }.join
   #  sha1 = Digest::SHA1.hexdigest(password)
   return password
end

#
#************************************************** start work here ****
#
def create_user(username,first,last,app)
  password = random_password
  STDERR.puts "#{$count} Creating user #{username}." if $options.verbose
  STDERR.puts "#{$count} Creating user #{username} with password #{password}." if $options.debug

  begin
    result = app.provision.create_user(username, first, last, password)
    STDERR.puts "Result: #{result}" if $options.debug
    update = true
  rescue GData::GDataError => e
    if e.code == "1300"
      STDERR.puts "  => Create User #{username} exists" if $options.verbose
      update = true
    elsif e.code == "1000"
      STDERR.puts "  => Create User #{username} unknown error" if $options.verbose
      update = false
      #retry
    else
      puts "Error creating user: #{username}" if $options.verbose
      raise e
    end
  end
end

# updates it so they don't have to change their password at next login
def disable_password_reset(username, first, last, app,config)
  puts "    Setting password reset to false for |#{username}|." if $options.verbose
  # need to get the admin setting code put in place NOTENOTENOTE
  # if config['source']['admins'].include?(nickname)
  #   admin = true
  # else
  #   admin = false
  # end
  admin = false
  begin
    result = app.provision.update_user(username, first, last, nil, nil, admin.to_s, nil, "false", nil )
    STDERR.puts "Result: #{result}" if $options.debug
    update = true
  rescue GData::GDataError => e
    if e.code == "1300"
      STDERR.puts "  => Set password reset to false #{username} exists" if $options.verbose
      update = true
    elsif e.code == "1000"
      STDERR.puts "  => setting password reset to false  #{username} unknown error" if $options.verbose
      update = false
      #retry
    else
      STDERR.puts "Error creating user: #{username}" if $options.verbose
      raise e
    end
  end
end

def add_alias(apps,username,nickname)
  #where nickname is the alias like h56t789, ben.livingood  is
  # translated to h56t789 is also known as ben.livingood
  begin
    puts "    Adding alias |#{nickname}| to |#{username}|." if $options.verbose
    result = apps.provision.create_nickname(username, nickname)
       puts "Result: #{result}" if $options.debug
    update = true
  rescue GData::GDataError => e
    if e.code == "1300"
      puts "  => adding alias #{nickname} to  #{username} exists" if $options.verbose
      update = true
    elsif e.code == "1000"
      puts "  => adding alias #{nickname} to  #{username} unknown error" if $options.verbose
      update = false
      #retry
    else
      puts "Error creating user: #{username}" if $options.verbose
      raise e
    end
  rescue OpenSSL::SSL::SSLError => e
    retry
  end
end

def sendas_alias(app,config,userH,nickname)
  first = userH["first"] #these should be the roster columns not the google ones
  last = userH["last"]
  username = userH["netid"]

  if config['domains'][app.domain]['domain'] != config['domains'][app.domain]['maildomain']
    send_as_name = "#{first} #{last}"
    send_as_alias = "#{nickname}@#{config['domains'][app.domain]['maildomain']}"
    begin
      # Add the email address they're used to seeing
      STDERR.puts "    Adding sendas_alias |#{send_as_name}| / |#{send_as_alias}| to |#{username}|." if $options.verbose
      #the last argument(true)  means it's now the default
      result = app.mail.create_send_as(username, send_as_name, send_as_alias, send_as_alias, true)
      STDERR.puts "Result: #{result}" if $options.debug
       update = true
    rescue GData::GDataError => e
      if e.code == "1300"
        STDERR.puts "  => creating send as alias #{send_as_name} for  #{username} exists" if $options.verbose
        update = true
      elsif e.code == "1000"
        STDERR.puts "  => creating send as alias #{send_as_name} for  #{username} uknown error" if $options.verbose
        update = false
        #retry
      else
        STDERR.puts "Error creating user: #{username}" if $options.verbose
        raise e
      end
    end
  end
end

#--
# get the time converted into a Time class
def convert_time(stime)
  begin
    if stime
      stime =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/;
      return Time.gm($1,$2,$3,$4,$5,$6).to_i
    else
      return 0
    end
  rescue
    return 0
  end
end

def refresh_absent_keys(absent_google_keys, apps, state_db)
  really_absent = []

  worker = []
  queue = absent_google_keys.sort{ rand(5)} / $options.threads
  queue.each_with_index do |absent_group,k|
    absent_group.each_with_index do |entry,i|
      worker[i] = Thread.new do
        user = apps.provision.retrieve_user(entry)
        if user.respond_to? :username
          nicks = apps.provision.retrieve_nicknames(user.username)
          if nicks
            na = nicks.map{ |n| n.nickname }
          end

          state_db.update_google(user.username, user.given_name, user.family_name, apps.domain, user.admin, na)

        else
          really_absent << entry
        end
        STDERR.puts "absent thread #{i} exit" if $options.debug
        Thread.exit
      end
      worker.each { |w| w.join}
    end
    STDERR.puts "Refresh: " + (100 * k.to_f / queue.length.to_f).to_s + "%" if $options.debug
  end
  return really_absent
end

def update_google_user(entry, app, state_db)
  user = app.provision.retrieve_user(entry)
  if user.respond_to? :username
    nicks = app.provision.retrieve_nicknames(user.username)
    if nicks
      na = nicks.map{ |n| n.nickname }
    end

    state_db.update_google(user.username, user.given_name, user.family_name, app.domain, user.admin, na)

    return nil   #they existed upstream, we just hadn't grabbed them
  else
    return entry #they really are absent from upstream
  end
end


def is_changed(google_entry, user_entry)
  if  google_entry
    if user_entry["last"] != google_entry["last_name"] or
        user_entry["first"] != google_entry["first_name"]
      STDERR.puts "*CHANGED* First: #{user_entry["first"]} -> google= #{google_entry["first_name"]}  Last name: #{user_entry["last"]} -> google= #{google_entry["last_name"]} - #{user_entry["last_modified"]} and #{user_entry["first_last"]}" if $options.debug
      return true
    else
      return false
    end
  else
    return false
  end
end

# --------------------------------------------------


# --------------------------------------------------
# Parse commandline options
OptionParser.new do |opts|
   $options.verbose = false
   $options.config = 'config.yml'
   $options.reset = false
   $options.statedbfn = nil
   $options.doit = true
   $options.threads = 1
   $options.forward = false
  $options.date = false
  $options.dryrun = false
  $options.new_users = false
  $options.changed_users = false
  $options.user = nil

  opts.banner = "Usage: gapps-provision.rb [options]"

  opts.on("-n", "--dryrun", "Just output what would be changed.") do |o|
    $options.dryrun  = true
    $options.debug   = true
    $options.verbose = true
  end

  opts.on("-c", "--config [FILE]", "Specify a config file.") do |o|
    $options.config = o.to_s
  end

  opts.on("-v", "--verbose", "Operate verbosely ;not implemented;") do |o|
    $options.verbose = true
  end

  opts.on("-d", "--debug", "debugging output") do |o|
    $options.debug = true
  end


  opts.on("-s", "--statdb [DBFILE]", "State Database file.") do |o|
    $options.statedbfn = o
  end

  opts.on("-D", "--date [DATE]", "run as if the date timestamp was X. Example -D 20090927121300Z, -D w/ nothing is Date = 0") do |o|
    $options.date = convert_time(o)
  end

  opts.on("-t", "--threads [# THREADS]", "The number of threads to run in parallel.") do |o|
    $options.threads = o.to_i
  end

  opts.on("-u", "--userid [NETID]", "The netid of the user") do |o|
    $options.user = o.to_s
  end

  opts.on_tail("--version", "Show version") do
    puts OptionParser::Version.join('.')
  end
end.parse!

if ! $options.user
  puts "Please enter a netid (use -u NETID)"
  exit
end

# Load configuration file
config = YAML.load_file($options.config)

# Create the Google Apps user and objects
apps = []
config["domains"].keys.each { |domain|
  user = config["domains"][domain]["user"]+"@"+config["domains"][domain]["domain"]
  apps << GData::GApps.new(user, config["domains"][domain]["password"])

}


#--------------------------------------------------
# act on options

if $options.statedbfn.nil?
  $options.statedbfn = config["state"]["file"]
end

# Create a local state store for keeping track of things between runs
state_db = State.new($options.statedbfn)

if $options.reset && ! $options.dryrun

  # Rebuild Google data in statedb from google
  benchmark = Benchmark.realtime do
    state_db.reset_google
  end
  puts "reset took " + sprintf("%.5f", benchmark) + "second(s)." if $options.debug
  benchmark = Benchmark.realtime do
    state_db.init_google
  end
  puts "init took " + sprintf("%.5f", benchmark) + "second(s)." if $options.debug

  apps.each do |app|
    STDERR.puts "Retrieving #{ app.domain } at #{Time.now} " if $options.debug
    users = app.provision.retrieve_all_users
    STDERR.puts "Finished retrieving the users for #{app.domain} -- " if $options.debug

    workers = []
    queue = users / $options.threads #split the array into chunks of thread length

    queue.each_with_index do |users,k|
      users.each_with_index do |user,i|
        workers[i] = Thread.new do
          #STDERR.puts (i.to_f / users.length) if $options.debug
          STDERR.puts user.username if $options.debug
          nicks = app.provision.retrieve_nicknames(user.username)
          na = nicks.map{ |n| n.nickname }
          state_db.update_google(user.username, user.given_name, user.family_name, app.domain, user.admin, na)
          STDERR.puts "Thread #{i} exiting" if $options.debug
          Thread.exit
        end
      end
      workers.each { |w| w.join}
      STDERR.puts("#{app.domain}: " + (100 * k.to_f / queue.length.to_f).to_s + "%") if $options.debug
    end
  end

end #resetting/creating the db

# --------------------------------------------------
#
userA = Array.new
googleA = Array.new

state_db.users {|user| userA << user}
state_db.google { |goog| googleA = goog }

date = convert_time(state_db.timestamp.to_s) #when did we last google provision
date = 0 if $options.reset # everyone needs to be included
date = $options.date if $options.date

googleH = googleA.inject({}){|h, item| h[item["username"]] = item ; h }

queue = userA.inject([]){ |a,user|

  a << user if user["netid"] == $options.user ; a
}

#populate the queue with all the user+app tuples that have changed
total_changed = []
apps.each do |app|
  potentials = queue.select do |user|
      user[ config["domains"][app.domain]["db_key"] ] == "1"
  end
  total_changed += potentials.map { |user| [user, app] } if potentials.length > 0
end

queue = total_changed

if $options.dryrun
  p queue

  exit
end

queue.each do |unit|
  key = unit[0]
  app = unit[1]
  #i shouldn't use first_last since it has been wrong in the past
  nickname =  key["first_last"] #key["first"].downcase+"."+key["last"].downcase

  create_user(key["netid"],key["first"], key["last"], app)
  disable_password_reset(key["netid"],key["first"], key["last"], app, config)
  app.provision.update_user(key["netid"],key["first"], key["last"])
  add_alias(app, key["netid"],nickname )
  sendas_alias(app, config, key, nickname)
  #need to update the db now
  update_google_user(key["netid"], app, state_db)
end

state_db.close
# --------------------------------------------------


#-- Notes

#google_keys = username, first_name, last_name, domain, admin, aliases
#roster keys = bl,bz,created,first,first_last,forward,gf,google,hv,idx,last,last_modified,netid
