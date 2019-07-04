class SRL::Entrant
  getter displayname
  getter place
  getter time
  getter message
  getter statetext
  getter twitch
  getter trueskill

  def initialize(
    @displayname : String,
    @place       : Int32,
    @time        : Time::Span,
    @message     : String,
    @statetext   : String,
    @twitch      : String,
    @trueskill   : String
  )
  end

  def self.from_json(raw)
    Entrant.new(
      raw["displayname"].as_s,
      raw["place"].as_i,
      raw["time"].as_i.seconds,
      raw["message"].as_s? || "",
      raw["statetext"].as_s,
      raw["twitch"].as_s,
      raw["trueskill"].as_s
    )
  end

  def ==(other : SRL::Entrant)
    @displayname = other.displayname
    @place = other.place
    @time = other.time
    @message = other.message
    @statetext = other.statetext
    @twitch = other.twitch
    @trueskill = other.trueskill
  end
end
