require "oauth2"
require "json"

class GoogleSheets::Authenticator
  TOKEN_PATH   = "./src/google-sheets/token.json"
  REFRESH_PATH = "./src/google-sheets/refresh.json"

  @client_id     : String
  @client_secret : String
  @redirect_uri  : String
  @authorize_uri : String
  @token_uri     : String

  getter! token  : OAuth2::AccessToken

  def initialize
    credentials = JSON.parse(File.open("./src/google-sheets/credentials.json"))["installed"]

    @client_id     = credentials["client_id"].as_s
    @client_secret = credentials["client_secret"].as_s
    @redirect_uri  = credentials["redirect_uri"].as_s
    @authorize_uri = credentials["auth_uri"].as_s
    @token_uri     = credentials["token_uri"].as_s

    @auth_client   = OAuth2::Client.new(
      "googleapis.com",
      @client_id,
      @client_secret,
      token_uri: @token_uri,
      redirect_uri: @redirect_uri
    )
  end

  def get_client
    begin
      @token = OAuth2::AccessToken::Bearer.from_json(File.open(TOKEN_PATH))
    rescue e : Exception
      puts "Please follow this link and paste the token you get in this terminal. #{auth_code}"
      code = gets.not_nil!


      @token = @auth_client.get_access_token_using_authorization_code(code)
      store_token
      store_refresh_token(self.token.refresh_token)
    end

    client = HTTP::Client.new("sheets.googleapis.com", tls: true)
    self.token.authenticate(client)

    client
  end

  def refresh_client
    @token = @auth_client.get_access_token_using_refresh_token(File.read(REFRESH_PATH).gsub(/"/, ""))
    client = HTTP::Client.new("sheets.googleapis.com", tls: true)
    self.token.authenticate(client)
    store_token

    client
  end

  def auth_code
    OAuth2::Client.new(
      "accounts.google.com",
      @client_id,
      @client_secret,
      authorize_uri: @authorize_uri,
      redirect_uri: @redirect_uri
    ).get_authorize_uri("https://www.googleapis.com/auth/spreadsheets")
  end

  def store_token
    File.open(TOKEN_PATH, "w") do |f|
      builder = JSON::Builder.new(f)
      builder.document do
        @token.to_json(builder)
      end
    end
  end

  def store_refresh_token(token)
    File.open(REFRESH_PATH, "w") do |f|
      builder = JSON::Builder.new(f)
      builder.document do
        token.to_json(builder)
      end
    end
  end
end
