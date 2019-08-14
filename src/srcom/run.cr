require "json"

class Run
  getter id         : String
  getter link       : String
  getter time       : Time::Span
  getter category   : Category
  getter players    : Array(String)
  getter video      : String
  getter status     : String
  getter comment    : String
  getter rej_reason : String?
  getter level      : Level?
  property rank     : Int32?

  def initialize(
    @id         : String,
    @link       : String,
    @time       : Time::Span,
    @category   : Category,
    @players    : Array(String),
    @video      : String,
    @status     : String,
    @comment    : String,
    @rej_reason : String?,
    @level      : Level?,
    @rank       : Int32?
  )
  end

  def self.from_json(raw_data)
    time = raw_data["times"]["primary_t"]
    video = (raw_data["videos"]["text"]? || raw_data["videos"]["links"][0]["uri"]).as_s
    status = raw_data["status"]["status"].as_s

    rej_reason = if status == "rejected"
      raw_data["status"]["reason"].as_s
    else
      nil
    end

    # I hate having to do this this way, but I think I have to. Unfortunately srcom's types aren't
    # consistent here, as the data is either an empty Array or a Hash. So I can't check if "id" is
    # present because that fails on an Array, I can't use as_h (or as_a) for the same reason, and I
    # can't use is_a? because it's JSON::Any either way. Thank you srcom :)
    # Nvm, this can probably done with .as_h? || as_a. I guess that's a TODO
    level = begin
      Level.from_json(raw_data["level"]["data"].as_h)
    rescue e : Exception
      nil
    end

    return Run.new(
      raw_data["id"].as_s,
      raw_data["weblink"].as_s,
      (time.as_i? || time.as_f? || raise "Invalid field: #{time}").to_f.seconds,
      Category.from_json(raw_data["category"]["data"]),
      raw_data["players"]["data"].as_a.map { |p| p["names"]["international"].as_s },
      video,
      status,
      raw_data["comment"].as_s? || "*No comment given*",
      rej_reason,
      level,
      nil
    )
  end

  def to_embed
    embed = Discord::Embed.new

    embed.description = @link

    fields = [Discord::EmbedField.new(
      name: (@status == "new" ? "Claims to be rank " : "Rank: ") + "#{@rank || "*Run not ranked*"}",
      value: "Time: #{time_string}\n" \
             "Category: #{@category.name}#{" - #{@level.try &.name}" if @level}\n" \
             "Player(s): #{@players.join(", ")}\n" \
             "Video: #{@video}\n" \
             "Comment: #{@comment}"
    )]

    embed.title = case @status
                  when "verified"
                    embed.colour = (@rank == 1 ? 0xffd700 : 0x00ff00).to_u32
                    "A run has been verified!"
                  when "rejected"
                    embed.colour = 0xff0000
                    fields << Discord::EmbedField.new(name: "Rejection reason", value: @rej_reason.not_nil!)
                    "A run has been rejected!"
                  when "new"
                    embed.colour = 0xb21e7b
                    "A new run is awaiting verification!"
                  end

    embed.fields = fields

    embed
  end

  def time_string
    String.build do |str|
      str << "#{@time.hours}:" unless @time.hours == 0
      str << "0" if @time.minutes < 10
      str << "#{@time.minutes}:"
      str << "0" if @time.seconds < 10
      str << "#{@time.seconds}."
      str << "#{@time.milliseconds}".ljust(3, '0')
    end
  end
end
