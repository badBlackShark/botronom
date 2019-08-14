class Botronom::Feedback
  include Discord::Plugin

  @first = true

  @@submissions = Hash(Discord::Snowflake, Array(Discord::Snowflake)).new
  @@bug_channel = Hash(Discord::Snowflake, Discord::Snowflake).new
  @@sug_channel = Hash(Discord::Snowflake, Discord::Snowflake).new
  # Stores the channels in which submissions were sent (good e.g. when a channel changes, but old stuff should still be accessible).
  @@channels    = Hash(Discord::Snowflake, Array(Discord::Snowflake)).new
  # Because we need that large an int for IDs :^)
  @@highest_id  = Hash(Discord::Snowflake, Int64).new

  private def init_table
    # The last two store the channel where the respective messages are posted
    Botronom.bot.db.create_table("shrk_feedback", ["guild int8", "submissions int8[]", "channels int8[]", "highest_id int8", "suggestions int8", "bugs int8"])
  end

  @[Discord::Handler(
    event: :guild_create
  )]
  def init_submissions(payload)
    if @first
      init_table
      @first = false
    end

    Botronom::Feedback.setup(payload.id, client) if PluginSelector.enabled?(payload.id, "feedback")
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("bug"),
      GuildChecker.new,
      EnabledChecker.new("feedback"),
      ArgumentChecker.new(1)
    }
  )]
  def bug(payload, ctx)
    guild   = ctx[GuildChecker::Result].id
    content = ctx[ArgumentChecker::Result].args.join(" ")
    id = @@highest_id[guild] += 1

    submission = Submission.new(
      id,
      SubmissionKind::Bug,
      payload.author,
      content,
      payload.attachments[0]?
    )

    msg = client.create_message(@@bug_channel[guild], "", submission.to_embed)
    @@submissions[guild] << msg.id
    @@channels[guild]    << msg.channel_id

    Botronom.bot.db.update_value("shrk_feedback", "submissions", "{#{@@submissions[guild].map(&.to_s).join(", ")}}", "guild", guild.to_s)
    Botronom.bot.db.update_value("shrk_feedback", "channels", "{#{@@channels[guild].map(&.to_s).join(", ")}}", "guild", guild.to_s)
    Botronom.bot.db.update_value("shrk_feedback", "highest_id", @@highest_id[guild], "guild", guild.to_s)

    client.create_message(payload.channel_id, "Successfully created bug with ID #{id}.")
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("suggest"),
      GuildChecker.new,
      EnabledChecker.new("feedback"),
      ArgumentChecker.new(1)
    }
  )]
  def suggest(payload, ctx)
    guild   = ctx[GuildChecker::Result].id
    content = ctx[ArgumentChecker::Result].args.join(" ")
    @@highest_id[guild] += 1

    submission = Submission.new(
      @@highest_id[guild],
      SubmissionKind::Suggestion,
      payload.author,
      content,
      payload.attachments[0]?
    )

    msg = client.create_message(@@sug_channel[guild], "", submission.to_embed)
    @@submissions[guild] << msg.id
    @@channels[guild]    << msg.channel_id

    Botronom.bot.db.update_value("shrk_feedback", "submissions", "{#{@@submissions[guild].map(&.to_s).join(", ")}}", "guild", guild.to_s)
    Botronom.bot.db.update_value("shrk_feedback", "channels", "{#{@@channels[guild].map(&.to_s).join(", ")}}", "guild", guild.to_s)
    Botronom.bot.db.update_value("shrk_feedback", "highest_id", @@highest_id[guild], "guild", guild.to_s)

    client.create_message(payload.channel_id, "Successfully created suggestion with ID #{@@highest_id[guild]}.")

    # Create rections later so the user gets faster feedback.
    client.create_reaction(msg.channel_id, msg.id, CHECKMARK)
    client.create_reaction(msg.channel_id, msg.id, CROSSMARK)
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("note"),
      GuildChecker.new,
      EnabledChecker.new("feedback"),
      ArgumentChecker.new(2)
    }
  )]
  def note(payload, ctx)
    guild   = ctx[GuildChecker::Result].id
    id      = ctx[ArgumentChecker::Result].args.first.to_i?
    content = ctx[ArgumentChecker::Result].args[1..-1].join(" ")

    unless id && id > 0 && id <= @@highest_id[guild]
      msg = client.create_message(payload.channel_id, "Please provide a numeric, positive ID smaller than #{@@highest_id[guild] + 1}.")
      sleep 5
      client.delete_message(payload.channel_id, msg.id)
      client.delete_message(payload.channel_id, payload.id)
      return
    end

    n = Note.new(payload.author, content)

    begin
      msg = client.get_channel_message(@@channels[guild][id - 1], @@submissions[guild][id - 1])

      embed = msg.embeds.first
      fields = embed.fields

      embed.fields = if fields
        fields << n.to_embed_field
      else
        [n.to_embed_field]
      end

      client.edit_message(msg.channel_id, msg.id, msg.content, embed)
      client.create_reaction(payload.channel_id, payload.id, CHECKMARK)
    rescue e : Exception
      puts e.message
      puts e.backtrace.join("\n")
      # Message could not be found
      client.create_message(payload.channel_id, "I could not find the message associated with that submission. Perhaps the message was deleted?")
    end
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("resolve"),
      GuildChecker.new,
      PermissionChecker.new(PermissionLevel::Moderator),
      EnabledChecker.new("feedback"),
      ArgumentChecker.new(1)
    }
  )]
  def resolve(payload, ctx)
    guild   = ctx[GuildChecker::Result].id
    id      = ctx[ArgumentChecker::Result].args.first.to_i?
    content = ctx[ArgumentChecker::Result].args[1..-1].join(" ")

    unless id && id > 0 && id <= @@highest_id[guild]
      msg = client.create_message(payload.channel_id, "Please provide a numeric, positive ID smaller than #{@@highest_id[guild] + 1}.")
      sleep 5
      client.delete_message(payload.channel_id, msg.id)
      client.delete_message(payload.channel_id, payload.id)
      return
    end

    n = Note.new(payload.author, content) unless content.empty?

    begin
      msg = client.get_channel_message(@@channels[guild][id - 1], @@submissions[guild][id - 1])

      embed = msg.embeds.first

      if n
        fields = embed.fields

        embed.fields = if fields
          fields << n.to_embed_field
        else
          [n.to_embed_field]
        end
      end

      embed.colour = 0x00FF00
      embed.footer = Discord::EmbedFooter.new(text: "#{embed.footer.not_nil!.text} - Marked as resolved by #{payload.author.username}##{payload.author.discriminator}.")

      client.edit_message(msg.channel_id, msg.id, msg.content, embed)
      client.create_reaction(payload.channel_id, payload.id, CHECKMARK)
    rescue e : Exception
      puts e.message
      puts e.backtrace.join("\n")
      # Message could not be found
      client.create_message(payload.channel_id, "I could not find the message associated with that submission. Perhaps the message was deleted?")
    end
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("setSuggestionChannel"),
      GuildChecker.new,
      PermissionChecker.new(PermissionLevel::Moderator),
      EnabledChecker.new("feedback")
    }
  )]
  def setSugChannel(payload, ctx)
    channel = payload.content.match(/<#(\d*)>/)
    if channel
      guild = ctx[GuildChecker::Result].id
      id = Discord::Snowflake.new(channel[1])
      @@sug_channel[guild] = id

      Botronom.bot.db.update_value("shrk_feedback", "suggestions", id.to_s, "guild", guild.to_s)

      Logger.log(guild, "The suggestion channel has been set to #{channel[0]}.", payload.author)
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
      Command.new("setBugChannel"),
      GuildChecker.new,
      PermissionChecker.new(PermissionLevel::Moderator),
      EnabledChecker.new("feedback")
    }
  )]
  def setBugChannel(payload, ctx)
    channel = payload.content.match(/<#(\d*)>/)
    if channel
      guild = ctx[GuildChecker::Result].id
      id = Discord::Snowflake.new(channel[1])
      @@sug_channel[guild] = id

      Botronom.bot.db.update_value("shrk_feedback", "bugs", id.to_s, "guild", guild.to_s)

      Logger.log(guild, "The bug channel has been set to #{channel[0]}.", payload.author)
      client.create_reaction(payload.channel_id, payload.id, CHECKMARK)
    else
      msg = client.create_message(payload.channel_id, "No channel was provided.")
      sleep 5
      client.delete_message(payload.channel_id, msg.id)
      client.delete_message(payload.channel_id, payload.id)
    end
  end

  def self.setup(guild : Discord::Snowflake, client : Discord::Client)
    highest_id = Botronom.bot.db.get_value("shrk_feedback", "highest_id", "guild", guild, Int64)

    if highest_id
      @@highest_id[guild] = highest_id
    else # This means this is a new server that doesn't have a db entry yet, so we create one.
      # The channels will be found later, just set them to 0 for now.
      Botronom.bot.db.insert_row("shrk_feedback", [guild, Array(Int64).new, Array(Int16).new, 0, 0, 0])
      @@highest_id[guild] = 0
    end

    @@submissions[guild] = Botronom.bot.db.get_value("shrk_feedback", "submissions", "guild", guild, Array(Int64)).not_nil!.map { |i| Discord::Snowflake.new(i.to_u64) }
    @@channels[guild]    = Botronom.bot.db.get_value("shrk_feedback", "channels", "guild", guild, Array(Int64)).not_nil!.map { |i| Discord::Snowflake.new(i.to_u64) }

    @@bug_channel[guild], code = ensure_channel("bugs", guild, client)
    case code
    when :success
    when :found
      client.create_message(@@bug_channel[guild], "I have set this as the channel where bug reports go. Staff can disable this feature with `disable feedback`.")
    else
      client.create_message(@@bug_channel[guild], "I have created this channel for bug reports. Staff can disable this feature with `disable feedback`.")
    end

    @@sug_channel[guild], code = ensure_channel("suggestions", guild, client)
    case code
    when :success
    when :found
      client.create_message(@@sug_channel[guild], "I have set this as the channel where suggestions go. Staff can disable this feature with `disable feedback`.")
    else
      client.create_message(@@sug_channel[guild], "I have created this channel for suggestions. Staff can disable this feature with `disable feedback`.")
    end
  end

  private def self.ensure_channel(name : String, guild : Discord::Snowflake, client : Discord::Client)
    channel = Botronom.bot.db.get_value("shrk_feedback", name, "guild", guild, Int64)

    if channel
      begin
        client.get_channel(channel.to_u64)
        return Discord::Snowflake.new(channel.to_u64), :success
      rescue e : Exception
        # The channel was deleted while the bot was offline.
      end
    end

    channel = client.get_guild_channels(guild).find { |channel| channel.name =~ /#{name}/ }.try(&.id)
    if channel
      Botronom.bot.db.update_value("shrk_feedback", name, channel.value.to_i64, "guild", guild.to_s)
      return channel, :found
    else
      channel = client.create_guild_channel(guild, name, Discord::ChannelType::GuildText, nil, nil).id
      client.edit_channel_permissions(channel, guild, "role", Discord::Permissions::None, Discord::Permissions::SendMessages)
      Botronom.bot.db.update_value("shrk_feedback", name, channel.value.to_i64, "guild", guild.to_s)
      return channel, :created
    end
  end
end
