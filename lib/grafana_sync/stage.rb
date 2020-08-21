require 'active_support/all'
require 'diffy'
require 'http'
# Must be after 'http' gem.
require 'httplog'
require 'io/console'
require 'logger'

module GrafanaSync
  class Stage
    delegate :config, :die, to: GrafanaSync

    DASHBOARDS_ROOT = "dashboards"
    FILE_ENCODING = "UTF-8"
    FILE_EXTENSION = ".json"
    CREDENTIALS = File.expand_path("~/.grafana_sync_rc")

    def initialize(stage:, make_folders: false, debug: false,
                   logger: Logger.new(STDERR, level: Logger::INFO))
      @stage_name = stage
      @make_folders = make_folders
      @logger = logger
      HttpLog.configure do |config|
        config.logger = logger
        config.log_connect = false
        config.log_data = debug
        config.log_response = debug
        config.log_benchmark = false
      end

      GrafanaSync.load_config()
      validate_config!
      @base_url = stage_config[:url].chomp("/")
      folder = stage_config[:folder]
      # If there's no folder specified in Grafana dashboard config then it's "General".
      @folder_name = (folder == "General") ? nil : folder
    end

    def pull
      FileUtils.mkdir_p(DASHBOARDS_ROOT)
      FileUtils.rm(dashboard_files)
      remote_dashboards.each do |title, db|
        @logger.info("Saving dashboard '#{title}'")
        IO.write(File.join(DASHBOARDS_ROOT, title+FILE_EXTENSION),
                 JSON.pretty_generate(db), encoding: FILE_ENCODING, mode: "w")
      end
    end

    def push
      dashboards_to_delete.each do |title, _db|
        @logger.info("Deleting dashboard '#{title}'")
        uid = dashboard_uid(title)
        http_delete("/api/dashboards/uid/#{uid}")
      end

      dashboards_to_update.each do |title, db|
        db["folderId"] = (folder_id or make_folder)
        db["overwrite"] = true
        @logger.info("Updating dashboard '#{title}'")
        http_post("/api/dashboards/db", json: db)
      end
    end

    def diff
      dashboards_to_delete.keys.each do |key|
        puts("--- #{@stage_name}/#{key}")
        puts("+++ /dev/null")
        puts
      end

      dashboards_to_update.keys.sort.each do |key|
        diff_str = Diffy::Diff.new(JSON.pretty_generate(remote_dashboards[key]),
                                   JSON.pretty_generate(local_dashboards[key]),
                                   context: 3, diff: '-w', include_diff_info: true).to_s(:color)
        unless diff_str.chop.empty?
          puts("--- #{@stage_name}/#{key}")
          puts("+++ local/#{key}")
          puts(diff_str)
        end
      end
    end

    private

    def validate_config!
      unless config.has_key?(@stage_name)
        die("There's no environment ':#{@stage_name}' defined in config.rb!")
      end

      config.keys.each do |stage|
        [:url, :folder].each {|key|
          die("config.rb has no :#{key} specified for :#{stage}!") if config[stage][key].nil?
        }

        config[stage][:datasource_replace].try do |ds_hash|
         if ds_hash.has_key?(nil) or ds_hash.has_value?(nil)
          die("config.rb:#{stage}: nil value in :datasource_replace is not supported!")
         end
        end
      end
    end

    def stage_config
      config[@stage_name]
    end

    def dashboards_to_delete
      remote_dashboards.slice(*(remote_dashboards.keys - local_dashboards.keys))
    end

    def dashboards_to_update
      local_dashboards
    end

    def remote_dashboards
      @remote_dashboards ||= dashboard_uids.lazy.map do |uid|
        db = http_get("/api/dashboards/uid/#{uid}")
        db.delete("meta")
        ["id", "uid", "version"].each {|key|
          db["dashboard"].delete(key)
        }
        [db["dashboard"]["title"], db]
      end.to_h
    end

    def dashboard_uid(title)
      index.find {|item| item["type"]=="dash-db" and item["title"]==title}
        .try {|item| item["uid"]}.tap {|val|
        die("Dashboard #{title} not found on #{@stage_name}!") if val.nil?
      }
    end

    def dashboard_uids
      index.filter {|item| item["type"]=="dash-db" and item["folderTitle"]==@folder_name}
        .map {|item| item["uid"]}.tap {|val|
        @logger.warn("No dashboards found on #{@stage_name}!") if val.empty?
      }
    end

    def folder_id
      @folder_id ||= if @folder_name.nil?
                       0  # "General" folder ID is always 0.
                     else
                       index.find {|item|
                         item["type"]=="dash-folder" and item["title"]==@folder_name
                       }.try {|item| item["id"] }
                     end
    end

    def make_folder
      die("""There is no folder '#{@folder_name}' for '#{@stage_name}'!
To create it add --make-folders option to command-line.""") unless @make_folders

      @logger.info("Making Grafana folder '#{@folder_name}'")
      response = http_post("/api/folders", json: {title: @folder_name})
      response["id"].tap {
        invalidate_index
      }
    end

    def invalidate_index
      @index = nil
    end

    def local_dashboards
      @local_dashboards ||= dashboard_files.map do |path|
        @logger.debug("Loading '#{path}'")
        db = JSON.parse(IO.read(path, encoding: FILE_ENCODING))
        title = db["dashboard"]["title"]
        next if stage_config[:exclude].try { |array| array.include?(title) }
        replace_datasources!(db)
        [title, db]
      end.compact.to_h
    end

    def dashboard_files
      # dashboards/*.json
      Dir.glob(File.join(DASHBOARDS_ROOT, '*'+FILE_EXTENSION))
    end

    def replace_datasources!(obj)
      replaces = stage_config[:datasource_replace]
      return if replaces.nil?

      if obj.is_a?(Hash)
        datasource = obj["datasource"]
        if datasource
          obj["datasource"] = replaces.fetch(datasource, datasource)
        end
        obj.each_value {|value| replace_datasources!(value)}
      elsif obj.is_a?(Array)
        obj.each {|value| replace_datasources!(value)}
      end
    end

    def index
      @index ||= http_get("/api/search")
    end

    def http_get(path)
      url = @base_url + path
      response = http.get(url)
      die("Failed to GET #{url}!") if response.code != 200
      JSON.parse(response.to_s)
    end

    def http_post(path, json: {})
      url = @base_url + path
      response = http.post(url, json: json)
      die("Failed to POST #{url}!") if response.code != 200
      JSON.parse(response.to_s)
    end

    def http_delete(path, json: {})
      url = @base_url + path
      response = http.delete(url, json: json)
      die("Failed to DELETE #{url}!") if response.code != 200
      JSON.parse(response.to_s)
    end

    def http
      @http ||= HTTP.basic_auth(user: credentials[:login],
                                pass: credentials[:password]).follow
    end

    def credentials
      @credentials ||= load_credentials or ask_credentials
    end

    def load_credentials
      if File.exist?(CREDENTIALS)
        JSON.parse(IO.read(CREDENTIALS, encoding: FILE_ENCODING)).transform_keys(&:to_sym)
      else
        nil
      end
    end

    def ask_credentials
      {login: ask_input("User: "),
       password: ask_input("Password: ", hide: true)}.tap do |cred_hash|
        IO.write(CREDENTIALS,
                 JSON.pretty_generate(cred_hash),
                 encoding: FILE_ENCODING, mode: "w")
      end
    end

    def ask_input(invitation, hide: false)
      print(invitation)
      if hide
        STDIN.noecho(&:gets).tap { puts }
      else
        STDIN.gets
      end.strip
    end
  end
end
