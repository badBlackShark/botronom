module Vectronom
  class Level
    def initialize(@name : String, @strats : Array(String?), @links : Array(String?), @pickups : Array(Int32?))
      @strats.each_with_index do |s, i|
        s = nil if s && (s.empty? || s == "-")

        @strats[i] = s
      end

      @links.each_with_index do |l, i|
        l = nil if l && (l.empty? || l == "-")

        @links[i] = l
      end
    end

    def to_embed
      embed = Discord::Embed.new

      embed.title = "Strats for #{@name}"

      level_strats = String.build do |str|
        str << (@strats[0] || "*No whole level strats*")
        str << "\nWatch how it's done: #{@links[0]}" if @links[0]
        str << "\nThere #{@pickups[0]? == 1 ? "is 1 pickup" : "are #{@pickups[0]} pickups"} on this level in total." if @pickups[0]
      end

      fields = [Discord::EmbedField.new(name: "Whole Level", value: level_strats)]

      1.upto(3) do |i|
        stage_strats = String.build do |str|
          str << (@strats[i] || "*No special strats for this stage.*")
          str << "\nWatch how it's done: #{@links[i]}" if @links[i]
          str << "\nThere #{@pickups[i]? == 1 ? "is 1 pickup" : "are #{@pickups[i]} pickups"} on this stage." if @pickups[i]
        end

        fields << Discord::EmbedField.new(name: "#{@name}-#{i}", value: stage_strats)
      end

      embed.fields = fields
      embed.colour = 0xb21e7b

      embed
    end

    def self.from_json(raw)
      raw = raw["values"].as_a
      name = raw.first.as_a.first.as_s

      strats  = Array(String?).new
      links   = Array(String?).new
      pickups = Array(Int32?).new

      raw.each do |row|
        row = row.as_a
        strats  << row[1]?.try &.as_s
        links   << row[2]?.try &.as_s
        pickups << row[3]?.try &.as_s.to_i
      end

      Level.new(name, strats, links, pickups)
    end
  end
end
