require 'grafana_sync/stage'
require 'grafana_sync/version'

module GrafanaSync
  class << self
    def load_config
      @load_config ||= load('config.rb')
    end

    def config
      @config ||= {}
    end

    def merge_config(file_config)
      config.merge!(file_config)
    end

    def die(msg)
      puts("""Error: #{msg}
Use --debug option to get verbose output.""")
      exit(false)
    end
  end
end
