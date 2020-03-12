require "tasker"
# TODO: DOCUMENT NEW COMMANDS
class Botronom::Srcom
  include Discord::Plugin

  @first = true

  @@apis        = Hash(Discord::Snowflake, SrcomApi).new
  @@runs        = Hash(Discord::Snowflake, Array(Run)).new
  @@categories  = Hash(Discord::Snowflake, Array(Category)).new
  @@channel     = Hash(Discord::Snowflake, Discord::Snowflake).new
  @@ranked_runs = Hash(Discord::Snowflake, Hash(String, Array(Run))).new
  @@matcher     = Hash(Discord::Snowflake, Utilities::FuzzyMatch).new
  @@notifs      = Hash(Discord::Snowflake, Bool).new
  @@schedulers  = Hash(Discord::Snowflake, Tasker::Repeat(Nil)).new

  private def init_table
    Botronom.bot.db.create_table("shrk_srcom", ["guild int8", "game varchar(10)", "channel int8", "notifs boolean"])
  end

  @[Discord::Handler(
    event: :guild_create
  )]
  def init_submissions(payload)
    if @first
      init_table
      @first = false
    end

    Botronom::Srcom.setup(payload.id, client) if PluginSelector.enabled?(payload.id, "srcom")
  end

  def self.setup(guild : Discord::Snowflake, client : Discord::Client)
    @@schedulers[guild]?.try(&.cancel)
    game_id = Botronom.bot.db.get_value("shrk_srcom", "game", "guild", guild, String)
    if game_id && !game_id.empty?
      @@apis[guild]       = SrcomApi.new(game_id)
      @@runs[guild]       = @@apis[guild].get_runs.map { |raw| Run.from_json(raw) }
      @@categories[guild] = @@apis[guild].get_categories.map { |raw| Category.from_json(raw) }
      @@matcher[guild]    = Utilities::FuzzyMatch.new(@@apis[guild].get_levels.map { |raw| raw["name"].as_s })

      @@channel[guild], code = ensure_speedrun_channel(guild, client)
      case code
      when :success
      when :found
        client.create_message(@@channel[guild], "I have set this as the channel where speedrun.com notifications go. Staff can disable this feature with `disable srcom` or just mute notifications with `mute srcom`.")
      else
        client.create_message(@@channel[guild], "I have created this channel for speedrun.com notifications. Staff can disable this feature with `disable srcom` or just mute notifications with `mute srcom`.")
      end

      @@notifs[guild] = Botronom.bot.db.get_value("shrk_srcom", "notifs", "guild", guild, Bool) || false

      rank_runs(guild)

      request_loop(guild, client)
    else
      @@notifs[guild] = false

      p Botronom.bot.db.get_value("shrk_srcom", "guild", "guild", guild, Int64).nil?

      # If this fails this is a new guild, otherwise they just didn't set a game
      if Botronom.bot.db.get_value("shrk_srcom", "guild", "guild", guild, Int64).nil?
        Botronom.bot.db.insert_row("shrk_srcom", [guild, "", 0, false])
      end
    end
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("mute"),
      GuildChecker.new,
      PermissionChecker.new(PermissionLevel::Moderator),
      ArgumentChecker.new(1),
      EnabledChecker.new("srcom")
    }
  )]
  def mute(payload, ctx)
    arg = ctx[ArgumentChecker::Result].args.first
    return unless arg == "srcom"
    guild = ctx[GuildChecker::Result].id
    if @@notifs[guild]
      @@notifs[guild] = false
      Botronom.bot.db.update_value("shrk_srcom", "notifs", false, "guild", guild)

      client.create_reaction(payload.channel_id, payload.id, CHECKMARK)
    else
      msg = client.create_message(payload.channel_id, "Notifications are already muted.")
      sleep 5
      client.delete_message(payload.channel_id, msg.id)
      client.delete_message(payload.channel_id, payload.id)
    end
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("unmute"),
      GuildChecker.new,
      PermissionChecker.new(PermissionLevel::Moderator),
      ArgumentChecker.new(1),
      EnabledChecker.new("srcom")
    }
  )]
  def unmute(payload, ctx)
    arg = ctx[ArgumentChecker::Result].args.first
    return unless arg == "srcom"
    guild = ctx[GuildChecker::Result].id
    if @@notifs[guild]
      msg = client.create_message(payload.channel_id, "Notifications are already enabled.")
      sleep 5
      client.delete_message(payload.channel_id, msg.id)
      client.delete_message(payload.channel_id, payload.id)
    else
      @@notifs[guild] = true
      Botronom.bot.db.update_value("shrk_srcom", "notifs", true, "guild", guild)

      client.create_reaction(payload.channel_id, payload.id, CHECKMARK)
    end
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("setGame"),
      GuildChecker.new,
      PermissionChecker.new(PermissionLevel::Moderator),
      ArgumentChecker.new(1),
      EnabledChecker.new("srcom")
    }
  )]
  def set_game(payload, ctx)
    msg = client.create_message(payload.channel_id, "Looking for your game and setting it up. This might take a while...")
    abbreviation = ctx[ArgumentChecker::Result].args.first
    guild = ctx[GuildChecker::Result].id

    game = SrcomApi.find_game(abbreviation)

    if game.is_a?(Symbol)
      client.create_message(payload.channel_id, "Unfortunately, I couldn't find that game. Did you use the correct abbreviation? `speedrun.com/<this-part-here>`")
    else
      id, name = game

      Botronom.bot.db.update_value("shrk_srcom", "game", id, "guild", guild)
      Botronom.bot.db.update_value("shrk_srcom", "notifs", true, "guild", guild)
      Botronom::Srcom.setup(guild, client)

      reply = "Set the game to \"#{name}\", with id `#{id}`. I have also enabled notifications for this game. "\
              "You can disable notifications with `mute srcom`."
      client.create_message(payload.channel_id, reply)
    end
    client.delete_message(msg.channel_id, msg.id)
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("wr"),
      GuildChecker.new,
      ArgumentChecker.new(1),
      EnabledChecker.new("srcom")
    }
  )]
  def wr(payload, ctx)
    guild = ctx[GuildChecker::Result].id
    return game_not_set(payload.channel_id, client) unless game_set?(guild)
    wr = find_top(1, ctx[ArgumentChecker::Result].args.join(" ").downcase, guild)

    if wr.is_a?(Symbol)
      case wr
      when :no_cat
        client.create_message(payload.channel_id, "I couldn't find that category. Valid categories are: #{@@categories[guild].map { |c| c.name }.uniq.join(", ")}.")
        return
      when :no_fg
        client.create_message(payload.channel_id, "That category doesn't appear to exist for full game.")
        return
      else
        client.create_message(payload.channel_id, "That category doesn't appear to exist for ILs.")
        return
      end
    end

    unless wr.first?
      client.create_message(payload.channel_id, "There are no runs in this category.")
      return
    end

    wr = wr.first

    embed = wr.to_embed
    embed.title  = "The world record for #{wr.category.name}#{" - #{wr.level.try &.name}" if wr.level}"
    embed.colour = 0xFFD700

    client.create_message(payload.channel_id, "", embed)
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("top"),
      GuildChecker.new,
      ArgumentChecker.new(2),
      EnabledChecker.new("srcom")
    }
  )]
  def top(payload, ctx)
    guild = ctx[GuildChecker::Result].id
    return game_not_set(payload.channel_id, client) unless game_set?(guild)

    n = ctx[ArgumentChecker::Result].args.first.to_i?

    unless n && n >= 1 && n <= 10
      client.create_message(payload.channel_id, "Your first argument needs to be an integer between 1 and 10.")
      return
    end

    topn = find_top(n, ctx[ArgumentChecker::Result].args[1..-1].join(" ").downcase, guild)

    if topn.is_a?(Symbol)
      case topn
      when :no_cat
        client.create_message(payload.channel_id, "I couldn't find that category. Valid categories are: #{@@categories[guild].map { |c| c.name }.uniq.join(", ")}.")
        return
      when :no_fg
        client.create_message(payload.channel_id, "That category doesn't appear to exist for full game.")
        return
      else
        client.create_message(payload.channel_id, "That category doesn't appear to exist for ILs.")
        return
      end
    end

    if topn.empty?
      client.create_message(payload.channel_id, "There are no runs in this category.")
      return
    end

    embed = Discord::Embed.new
    fields = Array(Discord::EmbedField).new

    topn.each do |run|
      embed.title = "The top #{topn.size == 1 ? "run" : "#{topn.size} runs"} in #{run.category.name}#{" - #{run.level.try &.name}" if run.level}"
      embed.description = "Couldn't display #{n} runs because there #{topn.size == 1 ? "is only 1 run" : "are only #{topn.size} runs"} on that board." if n > topn.size
      embed.colour = 0xb21e7b

      value = String.build do |str|
        str << "#{run.players.size == 1 ? "Player: " : "Players: "}#{run.players.join(", ")}\n"
        str << "Time: #{run.time_string}\n"
        str << "Link: #{run.link}"
      end

      fields << Discord::EmbedField.new(name: "Rank #{run.rank}", value: value)
    end

    embed.fields = fields
    client.create_message(payload.channel_id, "", embed)
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("runs"),
      GuildChecker.new,
      ArgumentChecker.new(0), # Just so I get the arg splitting for free :)
      EnabledChecker.new("srcom")
    }
  )]
  def runs(payload, ctx)
    guild  = ctx[GuildChecker::Result].id
    return game_not_set(payload.channel_id, client) unless game_set?(guild)

    player = ctx[ArgumentChecker::Result].args.join(" ")
    player = payload.author.username if player.empty?
    # Every player that has done any run in any category.
    players = @@ranked_runs[guild].values.map { |runs| runs.map { |run| run.players } }.flatten.uniq
    player_finder = Utilities::FuzzyMatch.new(players)

    player = player_finder.find(player)
    if player.empty?
      client.create_message(payload.channel_id, "It doesn't seem like that player has run this game.}")
      return
    end

    player_runs = @@ranked_runs[guild].values.map { |runs| runs.select { |run| run.players.includes?(player) } }.flatten

    # We do slices to not break the character limit.
    player_runs.sort_by { |r| "#{r.category.name}#{" - #{r.level.try &.name}" if r.level}" }.each_slice(15) do |runs_subset|
      embed = Discord::Embed.new
      embed.title  = "Every run of #{@@apis[guild].name} by #{player}"
      embed.colour = 0xb21e7b

      fields = Array(Discord::EmbedField).new

      runs_subset.each do |run|
        value = String.build do |str|
          str << "Time: #{run.time_string}\n"
          str << "Rank: #{run.rank}"
        end

        fields << Discord::EmbedField.new(name: "#{run.category.name}#{" - #{run.level.try &.name}" if run.level}: #{run.link}\n", value: value)
      end
      embed.fields = fields
      embed.footer = Discord::EmbedFooter.new(text: "If this is not the player you were looking for they probably don't run this game. I try to guess who you meant in case you misspell their name.")

      client.create_message(payload.channel_id, "", embed)
    end
  end

  private def find_top(n : Int32, raw_args : String, guild : Discord::Snowflake)
    # Sorting in case one category is a substring of another, so it matches the longer one (e.g. any% vs any% blindfolded).
    # The gsub is to ensure that all special regex characters are escaped, should they appear in a category name.
    category = raw_args.scan(/#{@@categories[guild].sort_by { |c| c.name.size }.reverse.map { |c| c.name.downcase.gsub(/[-[\]{}()*+?.,\^$|#\\]/) { |special| "\\#{special}" } }.join("|")}/).[0]?.try &.[0]
    return :no_cat unless category

    level = @@matcher[guild].find(raw_args.sub(category, "").strip)

    contenders = if level.empty?
      cat = @@categories[guild].find { |c| c.name.downcase == category && c.type == "per-game" }
      return :no_fg unless cat

      @@ranked_runs[guild][cat.id]
    else
      cat = @@categories[guild].find { |c| c.name.downcase == category && c.type == "per-level" }
      return :no_il unless cat

      all_il_runs = @@ranked_runs[guild][cat.id]
      all_il_runs.select { |run| run.level.try &.name == level  }
    end

    contenders[0..n-1]
  end

  # Establishes the order runs are in on the srcom boards, ranked by time, with the same rules
  # for runs getting obsolete. For co-op runs that's if both players have a better run on the boards,
  # not necessarily with the same partner as before.
  # We assume that platforms and regions obsolete each other. Unfortunately, the API doesn't tell
  # us whether or not that is actually the case, so we don't have a good way of determining this.
  def self.rank_runs(guild : Discord::Snowflake)
    @@ranked_runs[guild] = Hash(String, Array(Run)).new

    @@categories[guild].each do |cat|
      i = 1
      unordered = @@runs[guild].reject { |r| r.status != "verified" || r.category.id != cat.id }

      if cat.type == "per-level"
        @@ranked_runs[guild][cat.id] = Array(Run).new

        levels = unordered.map { |r| r.level.try &.id }
        levels.each do |level|
          i = 1

          unordered_level = unordered.select { |r| r.level.try &.id == level }

          ordered = Array(Run).new
          unordered_level.sort_by { |r| r.time }.each do |run|
            obsolete = run.players.select { |player| ordered.find { |r| r.players.includes?(player) } }.size == run.players.size
            unless obsolete
              ordered << run
              run.rank = i
              i += 1
            end
          end

          @@ranked_runs[guild][cat.id] += ordered
        end

        @@ranked_runs[guild][cat.id].uniq!
      else
        ordered = Array(Run).new
        unordered.sort_by { |r| r.time }.each do |run|
          obsolete = run.players.select { |player| ordered.find { |r| r.players.includes?(player) } }.size == run.players.size
          unless obsolete
            ordered << run
            run.rank = i
            i += 1
          end
        end

        @@ranked_runs[guild][cat.id] = ordered
      end

    end
  end

  def self.request_loop(guild, client)
    task = Tasker.instance.every(2.minutes) do
      all_runs = @@apis[guild].get_runs.map { |raw| Run.from_json(raw) }
      all_runs.reject { |run| !@@runs[guild].find { |r| r.id == run.id && r.status == run.status }.nil? }.each do |new_run|
        # This is to show what the potential rank of a newly submitted run would be, should it get verified.
        if new_run.status == "new" || new_run.status == "verified"
          cat_runs = if new_run.level
            @@ranked_runs[guild][new_run.category.id].select { |run| run.level == new_run.level }.dup
          else
            @@ranked_runs[guild][new_run.category.id].dup
          end
          cat_runs << new_run
          cat_runs.sort_by! { |run| run.time }
          # not_nil! because the compiler thinks cat_runs.index(new_run) can *technically* return nil
          new_run.rank = cat_runs.index(new_run).not_nil! + 1
        end
        client.create_message(@@channel[guild], "", new_run.to_embed) if @@notifs[guild]
      end
      @@runs[guild] = all_runs
      rank_runs(guild)
    end

    @@schedulers[guild] = task
  end

  private def self.ensure_speedrun_channel(guild, client)
    channel = Botronom.bot.db.get_value("shrk_srcom", "channel", "guild", guild, Int64)

    if channel
      begin
        client.get_channel(channel.to_u64)
        return Discord::Snowflake.new(channel.to_u64), :success
      rescue e : Exception
        # The channel was deleted while the bot was offline.
      end
    end

    channel = client.get_guild_channels(guild).find { |channel| channel.name.try(&.downcase) =~ /speedrunning|speedruns/ }.try(&.id)
    if channel
      Botronom.bot.db.update_value("shrk_srcom", "channel", channel.value.to_i64, "guild", guild.to_s)
      return channel, :found
    else
      channel = client.create_guild_channel(guild, "speedrunning", Discord::ChannelType::GuildText, nil, nil, nil, nil, nil, nil, nil).id
      Botronom.bot.db.update_value("shrk_srcom", "channel", channel.value.to_i64, "guild", guild.to_s)
      return channel, :created
    end
  end

  private def game_set?(guild)
    !@@apis[guild]?.nil?
  end

  private def game_not_set(channel_id, client)
    client.create_message(channel_id, "I'm not observing any game in this server. Moderators can set one with the `setGame` command.")
  end
end
