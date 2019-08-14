class Botronom::Command
  getter name : String

  def initialize(name : String)
    @name = name.downcase
  end

  def call(payload : Discord::Message, ctx : Discord::Context)
    guild = Botronom.bot.cache.resolve_channel(payload.channel_id).guild_id

    prefix = Prefix.get_prefix(guild)

    cmd = payload.content.downcase
    yield if cmd.starts_with?("#{prefix}#{@name} ") || cmd == prefix + @name
  end
end
