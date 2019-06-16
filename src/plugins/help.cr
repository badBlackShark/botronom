class Botronom::Help
  include Discord::Plugin

  @[Discord::Handler(
    event: :message_create,
    middleware: Command.new("help")
  )]
  def help(payload, _ctx)
    bot = client.cache.try &.resolve_current_user || raise "Cache unavailable"

    embed        = Discord::Embed.new
    embed.author = Discord::EmbedAuthor.new(name: bot.username, icon_url: bot.avatar_url)
    embed.title  = "All the commands for Botronom"

    fields = Array(Discord::EmbedField).new

    fields << Discord::EmbedField.new(name: ".info", value: "Displays some info about the development of this bot.")
    fields << Discord::EmbedField.new(name: ".strats <category> <level>", value: "Shows you the current strats for <level> in <category>. Level names are fuzzy matched.")
    fields << Discord::EmbedField.new(name: ".wr <category> <level>", value: "Shows you the current world record in <category>, uses the IL if <level> was provided.")
    fields << Discord::EmbedField.new(name: ".top <n> <category> <level>", value: "Shows you the top <n> runs in <category>, uses the IL if <level> was provided. Can't show more than 10 runs.")
    fields << Discord::EmbedField.new(name: ".runs <player>", value: "Shows you all runs for <player>. If not given, defaults to your Discord username. Player names are fuzzy matched.")

    embed.fields = fields
    embed.colour = 0xb21e7b

    client.create_message(payload.channel_id, "", embed)
  end

  @[Discord::Handler(
    event: :ready
  )]
  def set_game(payload)
    # For some reason I need to send this 0, otherwise Discord refuses to update the game.
    client.status_update(game: Discord::GamePlaying.new("Vectronom | .help", 0.to_i64))
  end
end
