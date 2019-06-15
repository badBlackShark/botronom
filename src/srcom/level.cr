require "json"

class Level
  getter id
  getter name

  def initialize(@id : String, @name : String)
  end

  def self.from_json(raw_data)
    return Level.new(raw_data["id"].as_s, raw_data["name"].as_s)
  end
end
