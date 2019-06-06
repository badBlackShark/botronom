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
    embed.title  = "All the commands for God's Matchmaking"

    fields = Array(Discord::EmbedField).new

    fields << Discord::EmbedField.new(name: ".info",          value: "Displays some info about the development of this bot.")
    fields << Discord::EmbedField.new(name: ".wr <category>", value: "Shows you the current world record in <category>.")

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
