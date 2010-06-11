#!/usr/bin/env ruby
#=========================================================================================
# Name: NUKEMULTIS.RB
# Purpose: This appears to remove from the google table users that have more than
#          one of the bz/bl/hv/gf flags set in the user table of rosterdb.sqlite.
#          Still trying to determine why - mb
# Inputs: roster:/home/academic/rosterdb.sqlite
# Outputs: A list of users that have been removed from the google table of rosterdb.sqlite
#          as near as I can tell
# Called From: Academic users crontab
# Calls to: None.
# Notes:
# =========================================================================================
#  
# Require Other Code/Libraries
require 'rubygems'
require 'sqlite3'
require 'sequel'

## 
# This converts the timestamp as stored in SQLite3 into a ruby Time object
# 
# @param [String] stime Time from SQLite3
# @return [Time] Ruby Time object with the same value as the input string.
# 
def convert_time(stime)
  begin
    if stime
      stime =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/;
      return Time.gm($1,$2,$3,$4,$5,$6)
    else
      return Time.now
    end
  rescue
    return Time.now
  end
end

##
# The main nukemultis program
# 
# This program is removing duplicate entries from the google_users table in the rosterdb 
# database.
# 

# Connect the rosterdb.sqlite database to the application through the DB object
DB = Sequel.sqlite('/home/academic/rosterdb.sqlite')

# Map the users and google table to the cached_users and google_users variables.
# These variables will behave as Arrays of Hashes with column names as keys into the hash for 
# each row in the table.
cached_users = DB[:users]
google_users = DB[:google]

# Loop over the cached users, filtering out any user who is on more than one campus
# This is determined because the bz, bl, hv, and gf flags will be set to 1 if the user is 
# active on that campus, so the sum of the flags will == 1 if they are active on one campus, 
# 2 if they are on two campuses, and so on.
users_on_more_than_one_campus = cached_users.filter { |user| (user.bz + user.bl + user.hv + user.gf) > 1 }

# Iterate over each user who is active on only one campus
users_on_more_than_one_campus.each do |user|
  # If the user's last modified is more recent than 3 days ago. (3 day * 24 hours * 60 minutes * 60 seconds)
  if (convert_time(user[:last_modified]) > (Time.now  - (3 * 24 * 60 * 60))) 
    # Output the current user
    puts google_users[ :username => user[:netid] ].inspect
  
    # Then we remove any other user found with the same netid from the google table
    google_users.filter( :username => user[:netid] ).delete
    
    # Pull out their netid
    netid = user[:netid]
    
    # If we don't find anymore users with the same netid, we've successfully deleted them
    if google_users.filter( :username == user[:netid] ).empty?
      puts "Google #{netid} cache deleted"
    end 
    
    # Show that we're moving to the next user in the output
    puts "--"
  end
end

