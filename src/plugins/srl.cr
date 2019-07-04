require "tasker"

class Botronom::Srl
  include Discord::Plugin

  GAME = "vectronom"

  @count       : Int32
  @races       : Array(SRL::Race)
  @live_races  : Array(SRL::LiveRace)
  @leaderboard : SRL::Leaderboard

  getter! channel : Discord::Snowflake

  def initialize
    @api         = SRL::Api.new(GAME)
    @count       = @api.race_count.to_i
    @races       = @api.pastraces
    @live_races  = @api.live_races
    @leaderboard = @api.leaderboard

    liverace_request_loop
    pastrace_request_loop
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("racecount")
    }
  )]
  def racecount(payload, ctx)
    client.create_message(payload.channel_id, "There #{@count == 1 ? "has been 1 race" : "have been #{@count} races" } so far.")
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("last"),
      ArgumentChecker.new(0, 1)
    }
  )]
  def last(payload, ctx)
    args = ctx[ArgumentChecker::Result].args

    if args.empty?
      client.create_message(payload.channel_id, "", @races.first.to_embed)
    else
      n = args.first.to_i?
      unless n && n >= 1 && n <= 5
        client.create_message(payload.channel_id, "You must provide an integer between 1 and 5.")
        return
      end
      embed = Discord::Embed.new

      descr = String.build do |str|
        str << "**[#{@races.first.game.name}](http://www.speedrunslive.com/races/game/#!/#{@races.first.game.abbrev}/1)**\n"
        str << "Showing the #{n == 1 ? "most recent race" : "#{n} most recent races"}."
      end

      embed.description = descr
      embed.colour = 0xe3c75e
      embed.fields = @races[0...n].map { |race| race.to_embed_field }

      client.create_message(payload.channel_id, "", embed)
    end
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("leaderboard")
    }
  )]
  def leaderboard(payload, ctx)
    client.create_message(payload.channel_id, "", @leaderboard.to_embed)
  end

  @[Discord::Handler(
    event: :guild_create
  )]
  def ensure_speedrun_channel(payload)
    # We can do this because the bot is only in one server
    @channel = (client.get_guild_channels(guild_id: payload.id).find { |c| c.name.try(&.downcase) == "speedrunning" } ||
               client.create_guild_channel(guild_id: payload.id, name: "speedrunning", type: Discord::ChannelType::GuildText, bitrate: nil, user_limit: nil)).id
  end

  private def liverace_request_loop
    Tasker.instance.every(30.seconds) do
      live_races = @api.live_races
      live_races.each do |race|
        unless (old = @live_races.find { |lr| lr.id == race.id })
          message = client.create_message(self.channel, "", race.race_created_embed)
          spawn { observe(message, race) }
        end
      end

      @live_races = live_races
    end
  end

  private def observe(message : Discord::Message, race : SRL::LiveRace)
    done = false
    task = Tasker.instance.every(15.seconds) do
      begin
        new_race = @api.single_race(race.id)

        unless race == new_race
          if new_race.state == 3
            embed = new_race.race_started_embed
            embed.title = "A race has been started!"
            Botronom.bot.client.edit_message(message.channel_id, message.id, "", embed)
            done = true
          elsif new_race.state == 5
            Botronom.bot.client.delete_message(message.channel_id, message.id)
          else
            Botronom.bot.client.edit_message(message.channel_id, message.id, "", new_race.race_created_embed)
          end
        end

        race = new_race
      rescue e : Exception
        # This means the race was deleted
        Botronom.bot.client.delete_message(message.channel_id, message.id)
        done = true
      end
    end

    while !done
      sleep 15
    end

    task.cancel
  end

  private def pastrace_request_loop
    Tasker.instance.every(5.minutes) do
      count        = @api.race_count.to_i
      @races       = @api.pastraces
      @leaderboard = @api.leaderboard

      if count > @count
        n = count - @count
        @races[0...n].each do |race|
          embed = race.to_embed
          embed.colour = 0x00ff00
          embed.title = "A new race has been recorded!"
          client.create_message(self.channel, "", embed)
        end
        client.create_message(self.channel, "The leaderboard now looks like this:", @leaderboard.to_embed)
      end

      @count = count
    end
  end
end
