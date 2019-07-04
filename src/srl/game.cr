class SRL::Game
  getter id
  getter name
  getter abbrev
  getter popularity
  getter popularityrank

  def initialize(
    @id : Int64,
    @name : String,
    @abbrev : String,
    @popularity : Float64,
    @popularityrank : Int32
  )
  end

  def self.from_json(raw)
    Game.new(
      raw["id"].as_i64,
      raw["name"].as_s,
      raw["abbrev"].as_s,
      (raw["popularity"].as_f? || raw["popularity"].as_i).to_f,
      raw["popularityrank"].as_i
    )
  end

  def ==(other : SRL::Game)
    @id = other.id
    @name = other.name
    @abbrev = other.abbrev
    @popularity = other.popularity
    @popularityrank = other.popularityrank
  end
end
