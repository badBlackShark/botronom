require "yaml"
require "discordcr"
require "discordcr-plugin"
require "discordcr-middleware"

require "./config"
require "./plugins/*"
require "./middlewares/*"
require "./srcom/*"

module Botronom
  class Bot
    getter client : Discord::Client
    getter client_id : UInt64
    getter cache : Discord::Cache
    delegate run, stop, to: client

    def initialize(token : String, @client_id : UInt64, shard_id, num_shards)
      @client = Discord::Client.new(token: "Bot #{token}", client_id: @client_id,
        shard: {shard_id: shard_id, num_shards: num_shards})
      @cache = Discord::Cache.new(@client)
      @client.cache = @cache
      register_plugins
    end

    def register_plugins
      Discord::Plugin.plugins.each { |plugin| client.register(plugin) }
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

  def self.run(config : Config)
    @@config = config

    config.shard_count.times do |id|
      bot = Bot.new(config.token, config.client_id, id, config.shard_count)
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
