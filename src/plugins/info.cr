class Botronom::Info
  include Discord::Plugin

  @[Discord::Handler(
    event: :message_create,
    middleware: Command.new("info")
  )]
  def info(payload, _ctx)
    bot = client.cache.try &.resolve_current_user || raise "Cache unavailable"

    embed             = Discord::Embed.new
    embed.author      = Discord::EmbedAuthor.new(name: bot.username, icon_url: bot.avatar_url)
    embed.description = "I was written in [Crystal](https://crystal-lang.org/) by [badBlackShark](https://github.com/badBlackShark/).\n"\
                        "My code can be found [here](https://github.com/badBlackShark/botronom)."
    embed.fields      = [Discord::EmbedField.new(
        name: "I was built using these packages",
        value:
          "**[discordcr](https://github.com/meew0/discordcr)** *by meew0*\n"\
          "**[discordcr-middleware](https://github.com/z64/discordcr-middleware)** *by z64*\n"\
          "**[discordcr-plugin](https://github.com/z64/discordcr-plugin)** *by z64*\n"\
          "**[tasker](https://github.com/spider-gazelle/tasker)** *by spider-gazelle*\n"\
          "**[crystal-db](https://github.com/crystal-lang/crystal-db)** *by crystal-lang*\n"\
          "**[crystal-pg](https://github.com/will/crystal-pg)** *by will*"
      )
    ]

    embed.colour = 0xb21e7b
    client.create_message(payload.channel_id, "", embed)
  end
end
