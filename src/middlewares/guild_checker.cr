# Checks if a command was called in a guild (as opposed to a DM channel.)
class Botronom::GuildChecker
  class Result
    getter id : Discord::Snowflake

    def initialize(@id : Discord::Snowflake)
    end
  end

  def call (payload : Discord::Message, ctx : Discord::Context)
    client = ctx[Discord::Client]
    guild = client.cache.try &.resolve_channel(payload.channel_id).guild_id
    if guild
      ctx.put(Result.new(guild))
      yield
    else
      client.create_message(payload.channel_id, "This command can only be used in a guild.")
    end
  end
end
