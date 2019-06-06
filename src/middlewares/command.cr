class Botronom::Command
  getter name : String

  def initialize(name : String)
    @name = "." + name.downcase # Prefix is set, seeing that this is a single server bot.
  end

  def call(payload : Discord::Message, context : Discord::Context)
    cmd = payload.content.downcase
    yield if cmd.starts_with?("#{@name} ") || cmd == @name
  end
end
