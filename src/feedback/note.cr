class Botronom::Note
  getter author  : Discord::User
  getter content : String

  def initialize(
    @author  : Discord::User,
    @content : String
  )
  end

  def to_embed_field
    Discord::EmbedField.new(name: "Note by #{@author.username}##{@author.discriminator}", value: @content)
  end
end
