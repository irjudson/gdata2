program = open("gapps-provision").readlines.join()

program.sub!("config = 'config.yml'", "config = 'myp.yml'")
program.sub!("statedbfn = nil", "statedbfn = 'partialmadegoogle.sqlite'")

puts program