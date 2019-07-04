class SRL::Leaderboard
  getter game
  getter leaders_count
  getter leaders
  getter unranked_count
  getter unranked

  def initialize(@game : Game, @leaders_count : Int32, @leaders : Array(Player), @unranked_count : Int32, @unranked : Array(Player))
  end

  def self.from_json(raw)
    Leaderboard.new(
      Game.from_json(raw["game"]),
      raw["leadersCount"].as_i,
      raw["leaders"].as_a.map { |player| Player.from_json(player, true) },
      raw["unrankedCount"].as_i,
      raw["unranked"].as_a.map { |player| Player.from_json(player, false) }
    )
  end

  def to_embed
    embed = Discord::Embed.new

    embed.title  = "SpeedRunsLive Leaderboard for #{@game.name}"
    embed.colour = 0xe3c75e
    embed.footer = Discord::EmbedFooter.new("Only showing up to top 10.")
    embed.description = "http://www.speedrunslive.com/races/game/#!/#{@game.abbrev}/1"

    fields = Array(Discord::EmbedField).new

    # We're not showing more than top 10
    (@leaders + @unranked)[0..9].each do |player|
      fields << Discord::EmbedField.new(name: player.name, value: "#{player.ranked ? "Rank: #{player.rank}" : "Unranked"}\nSkill: #{(player.trueskill * 100).to_i / 100.0}")
    end

    embed.fields = fields
    embed
  end
end
