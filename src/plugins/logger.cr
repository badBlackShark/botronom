class Botronom::Logger
  include Discord::Plugin

  # guild => channel
  @@log_channel = Hash(Discord::Snowflake, Discord::Snowflake).new

  @first = true

  private def init_table
    Botronom.bot.db.create_table("shrk_logger", ["guild int8", "channel int8"])
  end

  @[Discord::Handler(
    event: :guild_create
  )]
  def init_log_channel(payload)
    # Make sure that the table exists on startup. Should only be relevant the very first time the bot
    # starts up. I tried to use ready for this, but apparently that was too slow and I got an exception.
    if @first
      init_table
      @first = false
    end

    Botronom::Logger.setup(payload.id, client) if PluginSelector.enabled?(payload.id, "logger")
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("setLogChannel"),
      GuildChecker.new,
      PermissionChecker.new(PermissionLevel::Moderator),
      EnabledChecker.new("logging")
    }
  )]
  def set_log_channel(payload, ctx)
    channel = payload.content.match(/<#(\d*)>/)
    if channel
      guild = ctx[GuildChecker::Result].id
      id = Discord::Snowflake.new(channel[1])
      @@log_channel[guild] = id

      Botronom.bot.db.delete_row("shrk_logger", "guild", guild)
      Botronom.bot.db.insert_row("shrk_logger", [guild, id])

      Logger.log(guild, "This channel has been set as the log channel.", payload.author)
      client.create_reaction(payload.channel_id, payload.id, CHECKMARK)
    else
      msg = client.create_message(payload.channel_id, "No channel was provided.")
      sleep 5
      client.delete_message(payload.channel_id, msg.id)
      client.delete_message(payload.channel_id, payload.id)
    end
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("logChannel"),
      GuildChecker.new,
      EnabledChecker.new("logging")
    }
  )]
  def log_channel(payload, ctx)
    client.create_message(payload.channel_id, "This server's log channel is <##{@@log_channel[ctx[GuildChecker::Result].id]}>.")
  end

  def self.setup(guild : Discord::Snowflake, client : Discord::Client)
    log_channel = Botronom.bot.db.get_value("shrk_logger", "channel", "guild", guild, Int64)

    if log_channel
      begin
        client.get_channel(log_channel.to_u64)
        @@log_channel[guild] = Discord::Snowflake.new(log_channel.to_u64)
      rescue e : Exception
        # The channel was deleted while the bot was offline.
        Botronom.bot.db.delete_row("shrk_logger", "guild", guild)
      end
    end

    unless @@log_channel[guild]?
      log_channel = client.get_guild_channels(guild).find { |channel| channel.name =~ /log|mod|staff/ }.try(&.id)
      if log_channel
        @@log_channel[guild] = log_channel
        Botronom.bot.db.insert_row("shrk_logger", [guild, @@log_channel[guild]])
        client.create_message(@@log_channel[guild], "I have set this channel as my log channel. Staff can disable logging with the `disableLogging` command, or change the channel with `setLogChannel`.")
      else
        @@log_channel[guild] = client.create_guild_channel(guild, "logs", Discord::ChannelType::GuildText, nil, nil).id
        Botronom.bot.db.insert_row("shrk_logger", [guild, @@log_channel[guild]])
        client.create_message(@@log_channel[guild], "I have created this channel as my log channel. Staff can disable logging with the `disableLogging` command, or change the channel with `setLogChannel`.")
      end
    end
  end

  def self.log(guild_id : Discord::Snowflake, message : String, mod : Discord::User? = nil)
    if PluginSelector.enabled?(guild_id, "logging")
      message += " Action performed by `#{mod.username}##{mod.discriminator}`." if mod
      Botronom.bot(guild_id.to_u64).client.create_message(@@log_channel[guild_id], message)
    end
  end
end
