require "json"
require "http/client"

module SRL
  class Api
    BASE_URL = "api.speedrunslive.com/"

    def initialize(@game : String)
    end

    def race_count
      parser = JSON::PullParser.new(HTTP::Client.get(BASE_URL + "pastraces?game=#{@game}").body)
      parser.on_key("count") do
        return parser.read_int
      end
    end

    # I'm going to postulate here that there won't be more than 20 new races per update cycle.
    # Not assuming this gives us incredibly long startup times for games like alttphacks, seeing
    # that they have 14207 (and counting) recorded races.
    # Should this not hold true I'll adjust to grab the first two pages instead of only the first.
    def pastraces
      JSON.parse(HTTP::Client.get(BASE_URL + "pastraces?game=#{@game}").body)["pastraces"].as_a.map { |race| Race.from_json(race) }
    end

    def live_races
      JSON.parse(HTTP::Client.get(BASE_URL + "races").body)["races"].as_a.map { |race| LiveRace.from_json(race) }.select { |lr| lr.game.abbrev == @game }
    end

    def single_race(id : String)
      LiveRace.from_json(JSON.parse(HTTP::Client.get(BASE_URL + "races/#{id}").body))
    end

    def leaderboard
      Leaderboard.from_json(JSON.parse(HTTP::Client.get(BASE_URL + "leaderboard/#{@game}").body))
    end
  end
end
