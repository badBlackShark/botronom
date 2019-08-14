# This one is only used for the commands used to set and get a guild's prefix.
# Since I want those two commands to always use the `.` prefix a seperate middleware is used.
class SetPrefixCommand
  getter name : String

  def initialize(name : String)
    @name = name.downcase
  end

  def call(payload : Discord::Message, ctx : Discord::Context)
    cmd = payload.content.downcase
    yield if cmd.starts_with?("#{@name} ") || cmd == @name
  end
end
