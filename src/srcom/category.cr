require "json"

class Category
  getter id
  getter name
  getter type

  def initialize(@id : String, @name : String, @type : String)
  end

  def self.from_json(raw_data)
    return Category.new(raw_data["id"].as_s, raw_data["name"].as_s, raw_data["type"].as_s)
  end
end
