require "parallel"
require_relative "base"
require_relative "../helper/zip"
require 'open-uri'

module PodPrebuild
  class CacheFetcher < CommandExecutor
    @resolved_targets = []

    def initialize(options)
      super(options)
    end

    def run
      Pod::UI.step("Fetching cache") do
        FileUtils.mkdir_p(@config.prebuild_sandbox_path)
        @binary_installer = Pod::PrebuildInstaller.new(
          sandbox: Pod::PrebuildSandbox.from_standard_sandbox(installer.sandbox),
          podfile: installer.podfile,
          lockfile: installer.lockfile,
          cache_validation: nil
        )

        Pod::UI.title("Generate Manifest") do
          @binary_installer.clean_delta_file
          @binary_installer.install!
        end
        @resolved_targets = @binary_installer.pod_targets
        fetch_remote_cache(@config.cache_repo, @config.cache_path)
        unzip_cache
      end
    end

    private

    def fetch_remote_cache(repo, dest_dir)
      Pod::UI.puts "Fetching cache from #{repo}".green
      Parallel.each(@resolved_targets, in_threads: 1) do |name|
        to_dir = @config.generated_frameworks_dir(in_cache: true) + "/#{name}"
        unless to_dir.nil? 
          FileUtils.mkdir_p(to_dir)
        end
      end
      cache_paths = @resolved_targets.map {|target| "/#{target.name}/#{target.version}.zip"}
      Parallel.each(cache_paths, in_threads: 8) do |path|
        cache_path = @config.generated_frameworks_dir(in_cache: true) + path 
        if File.exists?(cache_path) == false || File.zero?(cache_path) == true
          File.open(cache_path, "wb") do |file|
            begin
              file.write open(repo + path, :http_basic_authentication => [@config.artifactory_login, @config.artifactory_password]).read
              Pod::UI.puts "Successful download from cache #{path}".green
            rescue OpenURI::HTTPError => error
              response = error.io
              response.status
              if response.status[0] == "404"
                Pod::UI.puts "Not found in cache #{path}".yellow
              else
                Pod::UI.puts "Error download cache (#{response.status[0]}) #{response.status[1]}".red
              end
              file.close unless file.closed? 
              File.delete(file)
            end
          end
        else
          Pod::UI.puts "Found in local cache #{path}".green
        end
      end
    end

    def unzip_cache
      Pod::UI.puts "Unzipping cache: #{@config.cache_path} -> #{@config.prebuild_sandbox_path}".green
      to_remain_files = ["Manifest.lock"]
      to_delete_files = @binary_installer.sandbox.root.children.reject { |file| to_remain_files.include?(File.basename(file)) }
      to_delete_files.each { |file| file.rmtree if file.exist? }
      if File.exist?(@config.manifest_path(in_cache: true))
        FileUtils.cp(
          @config.manifest_path(in_cache: true),
          @config.manifest_path
        )
      end      
      zip_paths = @resolved_targets.map {|target| @config.generated_frameworks_dir(in_cache: true) + "/#{target.name}/#{target.version}.zip"}
      Parallel.each(zip_paths, in_threads: 8) do |path|
        if File.exists? path
          ZipUtils.unzip(path, to_dir: @config.generated_frameworks_dir)
        end
      end
    end
  end
end
