class Botronom::Strats
  include Discord::Plugin

  def initialize
    # Vectronom Strats sheet
    @sheet   = GoogleSheets::Sheet.new("15SHEWGdbbT_C3Fyqe8CqSQwZ8luV6WLi4KoVlVy8f0c")
    @matcher = Utilities::FuzzyMatch.new(Vectronom::LevelList.levels.keys)
  end

  @[Discord::Handler(
    event: :message_create,
    middleware: {
      Command.new("strats"),
      ArgumentChecker.new(2)
    }
  )]
  def strats(payload, ctx)
    args = ctx[ArgumentChecker::Result].args

    category, level = if args.first.downcase == "any%"
      ["any%", args[1..-1].join(" ")]
    elsif args[0..1].join(" ").downcase == "all pickups"
      ["all pickups", args[2..-1].join(" ")]
    else
      client.create_message(payload.channel_id, "Please choose a valid category. Valid categories are \"Any%\" and \"All Pickups\".")
      return
    end

    level = @matcher.find(level)
    puts 1
    if level.empty?
      client.create_message(payload.channel_id, "No level with that name could be found.")
      return
    end
    puts 2
    raw = @sheet.get_level(category, Vectronom::LevelList.levels[level]).body
    puts "embed"
    client.create_message(payload.channel_id, "", Vectronom::Level.from_json(JSON.parse(raw)).to_embed)
  end
end
