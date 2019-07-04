class SRL::LiveRace
  # Just for displaying because of the Discord character limit
  MAX_ENTRANTS = 20

  getter id
  getter game
  getter goal
  getter time
  getter state
  getter statetext
  getter filename
  getter numentrants
  getter entrants


  def initialize(
    @id   : String,
    @game : Game,
    @goal : String,
    @time : Time,
    @state : Int32,
    @statetext : String,
    @filename : String,
    @numentrants : Int32,
    @entrants : Array(Entrant)
  )
  end

  def self.from_json(raw)
    id          = raw["id"].as_s
    game        = Game.from_json(raw["game"])
    goal        = raw["goal"].as_s
    time        = Time.unix(raw["time"].as_i)
    state       = raw["state"].as_i
    statetext   = raw["statetext"].as_s
    filename    = raw["filename"].as_s
    numentrants = raw["numentrants"].as_i
    entrants    = raw["entrants"].as_h.values.map { |entrant| Entrant.from_json(entrant) }

    LiveRace.new(id, game, goal, time, state, statetext, filename, numentrants, entrants)
  end

  def race_started_embed
    embed = Discord::Embed.new

    embed.title = @entrants.map { |r| r.displayname }.join(" vs ")
    embed.colour = 0xe3c75e
    embed.description = "[#{@game.name}](http://www.speedrunslive.com/races/game/#!/#{@game.abbrev}/1) - #{@goal}\n\nStarted on #{time_string}"

    fields = Array(Discord::EmbedField).new

    @entrants.sort_by { |e| e.trueskill.to_i }.reverse[0..1].each do |entrant|
      value = String.build do |str|
        str << "Rating: #{entrant.trueskill}\n"
        str << "Twitch: https://www.twitch.tv/#{entrant.twitch}" unless entrant.twitch.empty?
      end
      fields << Discord::EmbedField.new(name: "Player: #{entrant.displayname}", value: value)
    end
    if @entrants.size > MAX_ENTRANTS
      embed.footer = Discord::EmbedFooter.new(text: "...and #{@entrants.size - MAX_ENTRANTS} more.")
    end
    embed.fields = fields
    embed
  end

  def race_created_embed
    embed = Discord::Embed.new

    embed.title = "A new race has been created!"
    embed.colour = 0xe3c75e

    description = String.build do |str|
      str << "Game: [#{@game.name}](http://www.speedrunslive.com/races/game/#!/#{@game.abbrev}/1)\n"
      str << "Goal: #{@goal.empty? ? "*No goal set yet*" : @goal}\n"
      str << "#{@state == 1 ? "Entries are open!" : "Entries are closed."}"
    end


    unless @entrants.empty?
      embed.fields = [Discord::EmbedField.new(
        name:  "Entrants so far:",
        value: "• #{@entrants[0...MAX_ENTRANTS].sort_by { |e| e.trueskill.to_i }.reverse.map { |e| "#{e.displayname} (#{e.trueskill})" }.join("\n•")}"
      )]

      if @entrants.size > MAX_ENTRANTS # Discord character limit
        embed.footer = Discord::EmbedFooter.new(text: "\n...and #{@entrants.size - MAX_ENTRANTS} more.")
      end
    end

    embed.description = description

    embed
  end

  def time_string
    Time::Format.new("%A, %-d.%-m.%Y at %I:%M %p UTC", Time::Location.fixed("UTC", 0)).format(@time)
  end

  def ==(other : SRL::LiveRace)
    @id == other.id &&
    @game == other.game &&
    @goal == other.goal &&
    @time == other.time &&
    @state == other.state &&
    @statetext == other.statetext &&
    @filename == other.filename &&
    @numentrants == other.numentrants &&
    @entrants == other.entrants
  end

end
