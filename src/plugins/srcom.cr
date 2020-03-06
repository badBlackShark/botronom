require "tasker"

class Botronom::Srcom
  include Discord::Plugin

  getter api         : SrcomApi
  getter runs        : Array(Run)
  getter categories  : Array(Category)
  getter! channel    : Discord::Snowflake
  getter ranked_runs = Hash(String, Array(Run)).new

  # Only used for testing
  def initialize(@api : SrcomApi, @runs : Array(Run), @categories : Array(Category), @channel : Discord::Snowflake, @matcher : Utilities::FuzzyMatch)
  end

  def initialize
    @api        = SrcomApi.new("369p9931") # Vectronom
    @runs       = JSON.parse(@api.get_runs.body)["data"].as_a.map { |raw| Run.from_json(raw) }
    @categories = JSON.parse(@api.get_categories.body)["data"].as_a.map { |raw| Category.from_json(raw) }
    @matcher    = Utilities::FuzzyMatch.new(Vectronom::LevelList.levels.keys)

    rank_runs

    request_loop
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("wr"),
      ArgumentChecker.new(1)
    }
  )]
  def wr(payload, ctx)
    wr = find_top(1, ctx[ArgumentChecker::Result].args.join(" ").downcase)

    if wr.is_a?(Symbol)
      case wr
      when :no_cat
        client.create_message(payload.channel_id, "I couldn't find that category. Valid categories are: #{@categories.map { |c| c.name }.uniq.join(", ")}.")
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
      ArgumentChecker.new(2)
    }
  )]
  def top(payload, ctx)
    n = ctx[ArgumentChecker::Result].args.first.to_i?

    unless n && n >= 1 && n <= 10
      client.create_message(payload.channel_id, "Your first argument needs to be an integer between 1 and 10.")
      return
    end

    topn = find_top(n, ctx[ArgumentChecker::Result].args[1..-1].join(" ").downcase)

    if topn.is_a?(Symbol)
      case topn
      when :no_cat
        client.create_message(payload.channel_id, "I couldn't find that category. Valid categories are: #{@categories.map { |c| c.name }.uniq.join(", ")}.")
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
      ArgumentChecker.new(0) # Just so I get the arg splitting for free :)
    }
  )]
  def runs(payload, ctx)
    player = ctx[ArgumentChecker::Result].args.join(" ")
    player = payload.author.username if player.empty?
    # Every player that has done any run in any category.
    players = @ranked_runs.values.map { |runs| runs.map { |run| run.players } }.flatten.uniq
    player_finder = Utilities::FuzzyMatch.new(players)

    player = player_finder.find(player)
    if player.empty?
      client.create_message(payload.channel_id, "It doesn't seem like that player has run this game. Players that have submitted a run: #{players.join(", ")}")
      return
    end


    player_runs = @ranked_runs.values.map { |runs| runs.select { |run| run.players.includes?(player) } }.flatten

    # We do slices to not break the character limit.
    player_runs.sort_by { |r| "#{r.category.name}#{" - #{r.level.try &.name}" if r.level}" }.each_slice(15) do |runs_subset|
      embed = Discord::Embed.new
      embed.title  = "Every run of #{player}"
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

      client.create_message(payload.channel_id, "", embed)
    end
  end

  @[Discord::Handler(
    event: :guild_create
  )]
  def ensure_speedrun_channel(payload)
    # We can do this because the bot is only in one server
    @channel = (client.get_guild_channels(guild_id: payload.id).find { |c| c.name.try(&.downcase) == "speedrunning" } ||
               client.create_guild_channel(payload.id, "speedrunning", Discord::ChannelType::GuildText, nil, nil, nil, nil, nil, nil, nil)).id
  end

  private def find_top(n : Int32, raw_args : String)
    # Sorting in case one category is a substring of another, so it matches the longer one (e.g. any% vs any% 200)
    category = raw_args.scan(/#{@categories.sort_by { |c| c.name.size }.reverse.map { |c| c.name.downcase }.join("|")}/).[0]?.try &.[0]
    return :no_cat unless category

    level = @matcher.find(raw_args.sub(category, "").strip)

    contenders = if level.empty?
      cat = @categories.find { |c| c.name.downcase == category && c.type == "per-game" }
      return :no_fg unless cat

      @ranked_runs[cat.id]
    else
      cat = @categories.find { |c| c.name.downcase == category && c.type == "per-level" }
      return :no_il unless cat

      all_il_runs = @ranked_runs[cat.id]
      all_il_runs.select { |run| run.level.try &.name == level  }
    end

    contenders[0..n-1]
  end

  # Establishes the order runs are in on the srcom boards, ranked by time, with the same rules
  # for runs getting obsolete. For co-op runs that's if both players have a better run on the boards,
  # not necessarily with the same partner as before.
  def rank_runs
    @categories.each do |cat|
      i = 1
      unordered = @runs.reject { |r| r.status != "verified" || r.category.id != cat.id }

      if cat.type == "per-level"
        @ranked_runs[cat.id] = Array(Run).new

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

          @ranked_runs[cat.id] += ordered
        end

        @ranked_runs[cat.id].uniq!
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

        @ranked_runs[cat.id] = ordered
      end

    end
  end

  def request_loop
    Tasker.instance.every(2.minutes) do
      all_runs = JSON.parse(@api.get_runs.body)["data"].as_a.map { |raw| Run.from_json(raw) }
      all_runs.reject { |run| !@runs.find { |r| r.id == run.id && r.status == run.status }.nil? }.each do |new_run|
        # This is to show what the potential rank of a newly submitted run would be, should it get verified.
        if new_run.status == "new" || new_run.status == "verified"
          cat_runs = if new_run.level
            @ranked_runs[new_run.category.id].select { |run| run.level == new_run.level }.dup
          else
            @ranked_runs[new_run.category.id].dup
          end
          cat_runs << new_run
          cat_runs.sort_by! { |run| run.time }
          # not_nil! because the compiler thinks cat_runs.index(new_run) can *technically* return nil
          new_run.rank = cat_runs.index(new_run).not_nil! + 1
        end
        client.create_message(self.channel, "", new_run.to_embed)
      end
      @runs = all_runs
      rank_runs
    end
  end
end
