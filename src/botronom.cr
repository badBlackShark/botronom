require "yaml"
require "http"
require "discordcr"
require "discordcr-plugin"
require "discordcr-middleware"

require "./srl/*"
require "./srcom/*"
require "./config"
require "./helpers/*"
require "./plugins/*"
require "./utilities/*"
require "./feedback/*"
require "./middlewares/*"
require "./google-sheets/*"
require "./vectronom-levels/*"

module Botronom
  # Stuff used across all modules, especially heavily used emojis.
  CHECKMARK = URI.encode("\u2705")
  CROSSMARK = URI.encode("\u274C")

  class Bot
    getter client    : Discord::Client
    getter client_id : UInt64
    getter cache     : Discord::Cache
    getter db        : Db
    delegate run, stop, to: client

    def initialize(token : String, @client_id : UInt64, @db : Db, shard_id, num_shards)
      @client = Discord::Client.new(token: "Bot #{token}", client_id: @client_id,
        shard: {shard_id: shard_id, num_shards: num_shards})
      @cache = Discord::Cache.new(@client)
      @client.cache = @cache
      register_plugins
    end

    def register_plugins
      # We need to register the plugin selector first, because the setup of other stuff depends on it.
      # We only want to set certain things (like creating channels) up if a plugin is enabled in
      # the first place. If we don't register the plugin selector first we get a missing hash key.
      plugin_selector = Discord::Plugin.plugins.find { |plugin| plugin.is_a?(Botronom::PluginSelector) }.not_nil!
      client.register(plugin_selector)

      (Discord::Plugin.plugins - [plugin_selector]).each { |plugin| client.register(plugin) }
    end
  end

  class_getter! config : Config

  @@shards = [] of Bot

  def self.bot(guild_id : UInt64 | Discord::Snowflake | Nil = nil)
    if guild_id
      shard_id = (guild_id >> 22) % config.shard_count
      @@shards[shard_id]
    else
      @@shards[0]
    end
  end

  def self.run(config : Config, db : Db)
    @@config = config

    config.shard_count.times do |id|
      bot = Bot.new(config.token, config.client_id, db, id, config.shard_count)
      @@shards << bot
      spawn { bot.run }
    end
  end

  def self.stop
    @@shards.each do |bot|
      bot.stop
    end
  end
end
