require "json"
require "http/client"

class SrcomApi
  BASE_URL = "https://www.speedrun.com/api/v1/"

  getter game_id : String
  getter name    : String

  def initialize(@game_id : String)
    @name = JSON.parse(HTTP::Client.get(BASE_URL + "games/#{@game_id}").body)["data"]["names"]["international"].as_s
  end

  # TODO: This probably needs to get a lot smarter. For small games this implementation is fine, but
  # if we look at games such as sm64, we're fetching upwards of 14000 runs every time this gets called.
  # We should remember the offset at which we last checked, and only check from that page onwards.
  # srcom is nowhere neat the scale that more than 200 runs will be submitted to a single game within
  # whichever time period we end up with (2 mins rn).
  # Runs marked "new" should probably be stored separately and then queried for individually.
  # While queurying for single runs kinda sucks, unless mods leave like 50 runs unverified at a time
  # this should still drastically reduce the load we place on the API.
  def get_runs
    raw = JSON.parse(HTTP::Client.get(BASE_URL + "runs?game=#{@game_id}&max=200&embed=category,players,level").body)

    data = raw["data"].as_a

    while(!raw["pagination"]["links"].as_a.empty? && raw["pagination"]["links"].as_a[-1]["rel"].as_s == "next")
      raw = JSON.parse(HTTP::Client.get(raw["pagination"]["links"].as_a[-1]["uri"].as_s).body)
      data += raw["data"].as_a
    end

    return data
  end

  def get_categories
    JSON.parse(HTTP::Client.get(BASE_URL + "games/#{@game_id}/categories").body)["data"].as_a
  end

  def get_levels
    JSON.parse(HTTP::Client.get(BASE_URL + "games/#{@game_id}/levels").body)["data"].as_a
  end

  def self.find_game(abbreviation : String)
    raw = JSON.parse(HTTP::Client.get(BASE_URL + "games?_bulk=yes&max=1000").body)

    data = raw["data"].as_a
    game = data.find { |g| g["abbreviation"] == abbreviation }

    if game
      return [game["id"].as_s, game["names"]["international"].as_s]
    end

    while(raw["pagination"]["links"].as_a[-1]["rel"].as_s == "next")
      raw = JSON.parse(HTTP::Client.get(raw["pagination"]["links"].as_a[-1]["uri"].as_s).body)
      data = raw["data"].as_a

      game = data.find { |g| g["abbreviation"] == abbreviation }
      if game
        return [game["id"].as_s, game["names"]["international"].as_s]
      end
    end

    return :not_found
  end
end
