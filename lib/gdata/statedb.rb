require 'rubygems'
require 'sqlite3'
require 'digest/sha1'
require 'timestamp'

class State
   attr_reader :timestamp, :verbose

   def initialize(fn, timestamp="19700000000000Z", verb=false)
      @timestamp = nil
      @verbose = verb

      if !File.exists?(fn)
         needs_initialization = 1
      end

      puts "Creating new state database." if verbose

      @db = SQLite3::Database.new(fn)

      if needs_initialization
         do_initialization
      else
         @db.execute("SELECT * FROM updates;") do |@timestamp|
           # Doing nothing inside this loop
         end
      end
   end

   def init_google
      @db.execute("CREATE TABLE google (username TEXT PRIMARY KEY, first_name TEXT, last_name TEXT, domain TEXT, admin TEXT);")
      @db.execute("CREATE TABLE google_aliases (alias TEXT, g_username TEXT NOT NULL CONSTRAINT fk_google_id REFERENCES google(username) ON DELETE CASCADE);")
      @db.execute("CREATE TRIGGER fki_google_aliases_username BEFORE INSERT ON google_aliases FOR EACH ROW BEGIN SELECT RAISE(ROLLBACK, 'insert on table \"google\" violates foreign key constraint \"fk_google_id\"') WHERE (SELECT username FROM google WHERE username = NEW.g_username) IS NULL;END;")
      @db.execute("CREATE TRIGGER fku_google_aliases_username BEFORE UPDATE ON google_aliases FOR EACH ROW BEGIN SELECT RAISE(ROLLBACK, 'update on table \"google\" violates foreign key constraint \"fk_google_id\"') WHERE (SELECT username FROM google WHERE username = NEW.g_username) IS NULL;END;")
      @db.execute("CREATE TRIGGER fkd_google_aliases_username BEFORE DELETE ON google_aliases FOR EACH ROW BEGIN SELECT RAISE(ROLLBACK, 'delete on table \"google_id\" violates foreign key constraint \"fk_google_id\"') WHERE (SELECT g_username from google_aliases WHERE username = OLD.username) IS NOT NULL;END;")
   end

   def init_source
      @db.execute("CREATE TABLE updates (ts TEXT);")
      @db.execute("CREATE TABLE users (idx TEXT PRIMARY KEY, created TEXT, last_modified TEXT, roster_modified TEXT, netid TEXT, first TEXT, last TEXT, first_last TEXT, bz TEXT, bl TEXT, gf TEXT, hv TEXT, forward TEXT, google TEXT);")
   end

   def do_initialization
     puts "Initializing state database." if verbose
     init_source
     init_google
   end

   def reset_source

     begin
       @db.execute("DROP TABLE users;")
       @db.execute("DROP TABLE updates;")
     rescue SQLite3::SQLException => e
       puts "error ", e
     end

   end

   def reset_google

     begin
       @db.execute("DROP TABLE google;")
       @db.execute("DROP TABLE google_aliases;")
     rescue SQLite3::SQLException => e
       puts "error ", e
     end

   end

   def reset
     puts "Resetting state database." if $options.verbose
     reset_source
     init_source

     reset_google
     init_google

     @timestamp = "19700000000000Z"
     update_timestamp
   end

# --------------------------------------------------
# accessors
# note: these are returning the users as a hash per entry!!!!!

   def users
     rah = @db.results_as_hash
     @db.results_as_hash = true

     @db.execute("SELECT * FROM users;") do |user|
       yield user
     end

     @db.results_as_hash = rah
   end

   def google
     rah = @db.results_as_hash
     @db.results_as_hash = true

     # @db.execute("SELECT * FROM google;") do |google|
     #   yield google
     # end

     yield @db.execute("SELECT * FROM google;")

     @db.results_as_hash = rah
   end

   def google_aliases
     rah = @db.results_as_hash
     @db.results_as_hash = true

     @db.execute("SELECT * FROM google_aliases;") do |google|
       yield google
     end

     @db.results_as_hash = rah
   end

#
# --------------------------------------------------

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

   def update(entry, username, uid_alias, email_addr=nil, ts=nil)
      ts ||= Time.now.gmtime.strftime("%Y%m%d%H%M00Z")
      forward = Array.new
      google = 0
      bz = 0
      bl = 0
      gf = 0
      hv = 0
      entry.montanaEduPersonClassicRoles.each do |role|
        case role[0..3]
          when "bz_s": (fwalias = "#{uid_alias}@msu.montana.edu") && bz = 1 && google = 1
          when "bl_s": (fwalias = "#{uid_alias}@student.msubillings.edu") && bl = 1 && google = 1
          when "gf_s": (fwalias = "#{uid_alias}@my.msugf.edu") && gf = 1 && google = 1
          when "hv_s": (fwalias = "#{uid_alias}@students.msun.edu") && hv = 1 && google = 1
          when "bz_e", "bl_e", "gf_e", "hv_e": (fwalias = get_mail(entry)) && google = 0
          when "bz_ws","bl_ws","gf_ws","hv_ws": (fwalias = nil) && google = 0
          else
            puts "Unknown role found! #{role[0..3]}" if verbose
        end
       if ! forward.include?(fwalias) && ! fwalias.nil?
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
      first_name = first_name.sub(/'/,"\?'").sub('?','\\').gsub(/"/, '')
      last_name  = last_name.sub(/'/,"\?'").sub('?','\\').gsub(/"/, '')

      if ! exists?(entry.uniqueIdentifier)
        begin
            puts "Inserting #{entry.dn} with TS: #{ts}" if verbose
            puts "QUERY: "+"INSERT INTO users (idx, created, last_modified, roster_modified, netid, first, last, first_last, bz, bl, gf, hv, forward, google) VALUES ('#{entry.uniqueIdentifier}', '#{entry.createTimestamp}', '#{entry.modifyTimestamp}', '#{ts}', '#{username}', '#{first_name}', '#{last_name}', '#{uid_alias}', '#{bz}', '#{bl}', '#{gf}', '#{hv}', '#{forward.join(",")}', '#{google}')" if verbose
            @db.execute("INSERT INTO users (idx, created, last_modified, roster_modified, netid, first, last, first_last, bz, bl, gf, hv, forward, google) VALUES ('#{entry.uniqueIdentifier}', '#{entry.createTimestamp}', '#{entry.modifyTimestamp}', '#{ts}', '#{username}', \"#{first_name}\", \"#{last_name}\", '#{uid_alias}', '#{bz}', '#{bl}', '#{gf}', '#{hv}', '#{forward.join(",")}', '#{google}')")
        rescue SQLite3::SQLException => e
            puts "Exception inserting data in db ", e
            puts "QUERY: "+"INSERT INTO users (idx, created, last_modified, roster_modified, netid, first, last, first_last, bz, bl, gf, hv, forward, google) VALUES ('#{entry.uniqueIdentifier}', '#{entry.createTimestamp}', '#{entry.modifyTimestamp}', '#{ts}', '#{username}', '#{first_name}', '#{last_name}', '#{uid_alias}', '#{bz}', '#{bl}', '#{gf}', '#{hv}', '#{forward.join(",")}', '#{google}')"
        end
      else
        begin
          puts "Updating #{entry.dn} with TS: #{ts}" if verbose
          @db.execute("UPDATE users SET created = '#{entry.createTimestamp}', last_modified = '#{entry.modifyTimestamp}', roster_modified = '#{ts}', netid = '#{username}', first = \"#{first_name}\", last = \"#{last_name}\", first_last = '#{uid_alias}', bz = '#{bz}', bl = '#{bl}', gf = '#{gf}', hv = '#{hv}', forward = '#{forward.join(",")}', google = '#{google}' WHERE idx = '#{entry.uniqueIdentifier}'")
        rescue SQLite3::SQLException => e
          puts "Exception updating data in db ", e
          puts "QUERY: "+"UPDATE users SET last_modified = '#{ts}' WHERE idx = '#{entry}'"
        end
      end
    end

    def update_google(uname, fname, lname, domain, admin, aliases)
      begin
        first_name = fname.sub(/'/,"\?'").sub('?','\\').gsub(/"/, '') #FIXED: For D'Ann names and the "Nita" roster entry
        last_name  = lname.sub(/'/,"\?'").sub('?','\\').gsub(/"/, '') #FIXED: For O'Rourke names

        @db.execute("INSERT INTO google (username, first_name, last_name, domain, admin) VALUES ('#{uname}',\"#{first_name}\", \"#{last_name}\", '#{domain}', '#{admin}');")
      rescue SQLite3::SQLException => e
        if e.to_s.match(/syntax/) #is our insert syntax wrong?
          STDERR.puts "Syntax Exception: INSERT INTO google (username, first_name, last_name, domain, admin) VALUES ('#{uname}',\"#{first_name}\", \"#{last_name}\", '#{domain}', '#{admin}'); \t#{ e }"
        else
          if e.to_s.match(/unique/) #we've already seen them?
            STDERR.puts "Username not unique: #{uname} #{first_name} #{last_name} - #{domain}"
          else
            STDERR.puts "Exception inserting google user in db #{ e } - #{uname}"
             STDERR.puts "** Statement was: INSERT INTO google (username, first_name, last_name, domain, admin) VALUES ('#{uname}',\"#{first_name}\", \"#{last_name}\", '#{domain}', '#{admin}'); \t#{ e }"
          end
        end
      end

      if aliases.respond_to? :each
        aliases.each do |a|
          begin
            @db.execute("INSERT INTO google_aliases (alias, g_username) VALUES ('#{a}', '#{uname}');")
          rescue SQLite3::SQLException => e
            STDERR.puts "Exception inserting google alias in state db #{ e }"
          end
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
