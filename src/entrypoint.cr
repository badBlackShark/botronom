require "./botronom"

config = Botronom::Config.load("./src/config.yml")
Botronom.run(config)
sleep
