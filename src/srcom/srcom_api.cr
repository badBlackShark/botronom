require "json"
require "crest"

class SrcomApi
  BASE_URL = "https://www.speedrun.com/api/v1/"

  getter game_id : String

  def initialize(@game_id : String)
  end

  def get_runs
    # This needs to be adjusted to support pagination as soon as there are more
    # than 200 runs on the boards. This will likely never happen.
    Crest.get(BASE_URL + "runs?game=#{@game_id}&max=200&embed=category,players,level")
  end

  def get_categories
    Crest.get(BASE_URL + "games/#{@game_id}/categories")
  end
end
