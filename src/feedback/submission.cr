class Botronom::Submission
  getter id         : Int64
  getter kind       : SubmissionKind
  getter author     : Discord::User
  getter content    : String
  getter attachment : Discord::Attachment?

  def initialize(
    @id         : Int64,
    @kind       : SubmissionKind,
    @author     : Discord::User,
    @content    : String,
    @attachment : Discord::Attachment?
  )
  end

  def to_embed
    embed = Discord::Embed.new

    embed.author      = Discord::EmbedAuthor.new("#{@author.username}##{@author.discriminator}", nil, "https://cdn.discordapp.com/avatars/#{@author.id}/#{@author.avatar}.png")
    embed.description = @content
    embed.footer      = Discord::EmbedFooter.new(text: "ID: #{@id}")
    if a = @attachment
      embed.image = Discord::EmbedImage.new(a.url)
    end

    case @kind
    when SubmissionKind::Suggestion
      embed.title  = "Suggestion"
      embed.colour = 0x0000FF
    else
      embed.title  = "Bug report"
      embed.colour = 0xFF0000
    end

    embed
  end
end
