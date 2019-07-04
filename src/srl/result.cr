class SRL::Result
  getter race
  getter place
  getter player
  getter time
  getter message
  getter oldtrueskill
  getter newtrueskill

  def initialize(
    @race            : Int32,
    @place           : Int32,
    @player          : String,
    @time            : Time::Span,
    @message         : String,
    @oldtrueskill    : Int32,
    @newtrueskill    : Int32,
    @trueskillchange : Int32
  )
  end

  def self.from_json(raw)
    Result.new(
      raw["race"].as_i,
      raw["place"].as_i,
      raw["player"].as_s,
      raw["time"].as_i.seconds,
      raw["message"].as_s,
      raw["oldtrueskill"].as_i,
      raw["newtrueskill"].as_i,
      raw["trueskillchange"].as_i,
    )
  end

  def time_string
    if @time.seconds == -1
      "*Forfeited*"
    else
      String.build do |str|
        str << "#{@time.hours}:" unless @time.hours == 0
        str << "0" if @time.minutes < 10
        str << "#{@time.minutes}:"
        str << "0" if @time.seconds < 10
        str << "#{@time.seconds}"
      end
    end
  end

  def trueskillchange
    if @trueskillchange < 0
      @trueskillchange
    elsif @trueskillchange == 0
      "±0"
    else
      "+#{@trueskillchange}"
    end
  end
end
