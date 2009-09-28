@timestamp=Time.now.gmtime.strftime("%Y%m%d%H%M00Z")
db = ARGV[0] || 't-rosterdb.sqlite'
puts "sqlite3 #{db} 'DELETE FROM updates;'"
puts "sqlite3 #{db} \"INSERT INTO updates (ts) VALUES ('" + @timestamp +"');\""

