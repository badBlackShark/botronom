# This is NOT a representation of a Player at the /players/:id endpoint, but the version of a player
# returned on the /leaderboard endpoint. The /playres endpoint is not currently supported.
class SRL::Player
  getter name
  getter trueskill
  getter rank
  getter ranked

  def initialize(@name : String, @trueskill : Float64, @rank : Int32, @ranked : Bool)
  end

  def self.from_json(raw, ranked)
    Player.new(
      raw["name"].as_s,
      raw["trueskill"].as_f,
      raw["rank"].as_i,
      ranked
    )
  end
end
