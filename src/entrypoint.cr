require "./botronom"
require "./database/db"

puts "Connecting to database..."
db = Db.new
puts "done!"

config = Botronom::Config.load("./src/config.yml")
Botronom.run(config, db)
sleep
