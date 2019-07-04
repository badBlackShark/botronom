class SRL::Race
  # Just for displaying because of the Discord character limit
  MAX_ENTRANTS = 20

  getter id
  getter game
  getter goal
  getter date
  getter numentrants
  getter results


  def initialize(
    @id : String,
    @game : Game,
    @goal : String,
    @date : Time,
    @numentrants : Int32,
    @results : Array(Result)
  )
  end

  def self.from_json(raw)
    id          = raw["id"].as_s
    game        = Game.from_json(raw["game"])
    goal        = raw["goal"].as_s
    date        = Time.unix(raw["date"].as_s.to_i)
    numentrants = raw["numentrants"].as_i
    results     = raw["results"].as_a.map { |result| Result.from_json(result) }

    Race.new(id, game, goal, date, numentrants, results)
  end

  def to_embed
    embed = Discord::Embed.new

    embed.colour = 0xe3c75e
    embed.description = "**[#{@game.name}](http://www.speedrunslive.com/races/game/#!/#{@game.abbrev}/1) - #{@goal}**\n\nRecorded on #{time_string}"

    fields = Array(Discord::EmbedField).new

    @results[0...MAX_ENTRANTS].each do |result|
      value = String.build do |str|
        str << "Player: #{result.player}\n"
        str << "Time: #{result.time_string}\n"
        str << "Rating: #{result.oldtrueskill} -> #{result.newtrueskill} (#{result.trueskillchange})\n"
        str << "Comment: #{result.message}" unless result.message.empty?
      end

      fields << Discord::EmbedField.new(name: "Rank #{result.time.seconds == -1 ? "-" : result.place}", value: value)
    end
    if @results.size > MAX_ENTRANTS
      embed.footer = Discord::EmbedFooter.new(text: "...and #{@results.size - MAX_ENTRANTS} more.")
    end

    embed.fields = fields

    embed
  end

  def to_embed_field
    value = String.build do |str|
      str << "Goal: #{@goal}\n"
      str << "Winner: #{@results.first.player}\n"
      str << "Number of entrants: #{@numentrants}\n"
      str << "Recorded on #{time_string}"
    end
    Discord::EmbedField.new(name: "http://www.speedrunslive.com/races/result/#!/#{@id}", value: value)
  end

  def time_string
    Time::Format.new("%A, %-d.%-m.%Y at %I:%M %p UTC", Time::Location.fixed("UTC", 0)).format(@date)
  end
end
