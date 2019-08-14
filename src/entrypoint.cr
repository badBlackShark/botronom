require "./botronom"
require "./database/db"

print "Connecting to database..."
db = Db.new
puts "done!"

config = Botronom::Config.load("./src/config.yml")
Botronom.run(config, db)
sleep
