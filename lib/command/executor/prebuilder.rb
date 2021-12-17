require_relative "base"
require_relative "fetcher"

module PodPrebuild
  class CachePrebuilder < CommandExecutor
    attr_reader :repo_update, :fetcher, :pusher

    def initialize(options)
      super(options)
      @repo_update = options[:repo_update]
    end

    def run
      prebuild
      changes = PodPrebuild::JSONFile.new(@config.prebuild_delta_path)
      return if changes.empty?

      sync_cache(changes)
    end

    private

    def prebuild
      Pod::UI.step("Installation") do
        installer.repo_update = @repo_update
        installer.install!

      end
    end

    def sync_cache(changes)
      Pod::UI.step("Syncing cache") do
        FileUtils.cp(@config.manifest_path, @config.manifest_path(in_cache: true))
        clean_cache(changes["deleted"])
        zip_to_cache(changes["updated"])
      end
    end

    def zip_to_cache(pods_to_update)
      FileUtils.mkdir_p(@config.generated_frameworks_dir(in_cache: true))
      pods_to_update.each do |pod|
        Pod::UI.puts "- Update cache: #{pod}"
        currentTarget = installer.pod_targets.select {|e| e.name == pod}.first
        
        ZipUtils.zip(
          "#{@config.generated_frameworks_dir}/#{pod}",
          to_dir: "#{@config.generated_frameworks_dir(in_cache: true)}/#{currentTarget.name}/",
          name: "#{currentTarget.version}"
        )

        uri = URI.parse(@config.cache_repo + "/#{currentTarget.name}/#{currentTarget.version}.zip")
        file = "#{@config.generated_frameworks_dir(in_cache: true)}/#{currentTarget.name}/#{currentTarget.version}.zip"
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Put.new(uri.request_uri)
        request.basic_auth @config.artifactory_login, @config.artifactory_password
        request.body_stream = File.open(file)
        request["Content-Type"] = "multipart/form-data"
        request.add_field('Content-Length', File.size(file))
        response=http.request(request)
        if response.code == "201" 
            Pod::UI.puts "  Successfull uploaded #{pod} (#{response.code}) to artifactory".green
        else
            Pod::UI.puts "  Error upload #{pod} to artifactory".red
            Pod::UI.puts "#{response.body}".red
        end
      end
    end

    def clean_cache(pods_to_delete)
      pods_to_delete.each do |pod|
        Pod::UI.puts "- Clean up cache: #{pod}"
        FileUtils.rm_rf("#{@config.generated_frameworks_dir(in_cache: true)}/#{pod}.zip")
      end
    end
  end
end
