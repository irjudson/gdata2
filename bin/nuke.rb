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

require 'sequel'


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
# get the time converted into a Time class
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

# --------------------------------------------------


DB = Sequel.sqlite('/home/academic/gdata2/bin/rosterdb.sqlite')

cached_users = DB[:users]
google_users = DB[:google]

cached_users.filter {|o| (o.bz + o.bl + o.hv + o.gf) > 1}.each{|r| 
  if (convert_time(r[:last_modified]) > (Time.now  - (24 * 60 * 60))) 
    p google_users[ :username => r[:netid] ]
    google_users.filter( :username => r[:netid] ).delete

    username = r[:netid]
    if google_users.filter( :username == r[:netid] ).empty?
      puts "Google #{username} cache deleted"
    end 
    puts "--"
  end
}

