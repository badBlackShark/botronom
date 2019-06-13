require "http/client"
require "./authenticator"

module GoogleSheets
  class Sheet
    property client : HTTP::Client

    def initialize(@sheet_id : String)
      @authenticator = GoogleSheets::Authenticator.new

      @client = @authenticator.get_client
    end

    def get_level(table : String, range : String)
      a1_notation = if table == "any%"
        "Any%!#{range}"
      else
        "AllPickups!#{range}"
      end
      response = self.client.get("/v4/spreadsheets/#{@sheet_id}/values/#{a1_notation}")

      return get_level(table, range) if unauthorized?(response)

      response
    end

    private def unauthorized?(response)
      # Probably not the most elegant way to make sure we're authorized, but the only one I'm seeing
      # right now. I don't know how to make sure the token hasn't expired on startup, since
      # nothing fails until the first request gives me an UNAUTHORIZED. I could make sure on all
      # following tokens to refresh just after the TTL, but doing one request on startup to ensure
      # the token is still valid and then starting timers doesn't exactly feel elegant either.
      # What probably should be done is storing the timestamp the token was granted alongside the
      # token, and then making sure the token is still valid that way, but I don't feel like doing
      # that right now.
      if response.status_message == "Unauthorized"
        @authenticator.refresh_client(@client)
        return true
      end

      false
    end
  end
end
