require "tasker"

class Botronom::Srcom
  include Discord::Plugin

  getter api         : SrcomApi
  getter runs        : Array(Run)
  getter categories  : Array(Category)
  getter! channel    : Discord::Snowflake
  getter ranked_runs = Hash(String, Array(Run)).new

  # Only used for testing
  def initialize(@api : SrcomApi, @runs : Array(Run), @categories : Array(Category), @channel : Discord::Snowflake)
  end

  def initialize
    @api  = SrcomApi.new("369p9931") # Vectronom
    @runs = JSON.parse(@api.get_runs.body)["data"].as_a.map { |raw| Run.from_json(raw) }
    @categories = JSON.parse(@api.get_categories.body)["data"].as_a.map { |raw| Category.from_json(raw) }

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
    category = ctx[ArgumentChecker::Result].args.join(" ")
    wr = ranked_runs.find { |k, v| k.downcase == category.downcase }
    unless wr
      client.create_message(payload.channel_id, "No category \"#{category}\" was found. Are you sure it's spelled correctly?")
      return
    end

    run = wr[1].first?
    unless run
      client.create_message(payload.channel_id, "There are no runs in this category.")
      return
    end

    embed = run.to_embed
    embed.title  = "The world record for #{wr[0]}"
    embed.colour = 0xFFD700

    client.create_message(payload.channel_id, "", embed)
  end


  @[Discord::Handler(
    event: :guild_create
  )]
  def ensure_speedrun_channel(payload)
    # We can do this because the bot is only in one server
    @channel = (client.get_guild_channels(guild_id: payload.id).find { |c| c.name.try(&.downcase) == "speedrunning" } ||
               client.create_guild_channel(guild_id: payload.id, name: "speedrunning", type: Discord::ChannelType::GuildText, bitrate: nil, user_limit: nil)).id
  end

  # Establishes the order runs are in on the srcom boards, ranked by time, with the same rules
  # for runs getting obsolete. For co-op runs that's if both players have a better run on the boards,
  # not necessarily with the same partner as before.
  def rank_runs
    @categories.each do |cat|
      i = 1
      unordered = @runs.reject { |r| r.status != "verified" || r.category != cat.name }

      ordered = Array(Run).new
      unordered.sort_by { |r| r.time }.each do |run|
        obsolete = run.players.select { |player| ordered.find { |r| r.players.includes?(player) } }.size == run.players.size
        unless obsolete
          ordered << run
          run.rank = i
          i += 1
        end
      end

      @ranked_runs[cat.name] = ordered
    end
  end

  def request_loop
    Tasker.instance.every(2.minutes) do
      all_runs = JSON.parse(@api.get_runs.body)["data"].as_a.map { |raw| Run.from_json(raw) }
      all_runs.reject { |run| !@runs.find { |r| r.id == run.id && r.status == run.status }.nil? }.each do |new_run|
        # This is to show what the potential rank of a newly submitted run would be, should it get verified.
        if new_run.status == "new" || new_run.status == "verified"
          cat_runs = @ranked_runs[new_run.category].dup
          cat_runs << new_run
          cat_runs.sort_by! { |run| run.time }
          # not_nil! because the compiler things cat_runs.index(new_run) can *technically* return nil
          new_run.rank = cat_runs.index(new_run).not_nil! + 1
        end
        client.create_message(self.channel, "", new_run.to_embed)
      end
      @runs = all_runs
      rank_runs
    end
  end
end
