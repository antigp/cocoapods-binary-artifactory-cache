require_relative "executor/prebuilder"
require_relative "../cocoapods-binary-artifactory-cache/pod-binary/prebuild_dsl"

module Pod
  class Command
    class Binary < Command
      class Prebuild < Binary
        attr_reader :prebuilder

        self.arguments = [CLAide::Argument.new("CACHE-BRANCH", false)]
        def self.options
          [
            ["--config", "Config (Debug, Test...) to prebuild"],
            ["--repo-update", "Update pod repo before installing"],
            ["--all", "Prebuild all binary pods regardless of cache validation"],
            ["--targets", "Targets to prebuild. Use comma (,) to specify a list of targets"]
          ].concat(super)
        end

        def initialize(argv)
          super
          unless ENV['ARTIFACTORY_LOGIN'].nil? && ENV['ARTIFACTORY_PASSWORD'].nil?
            update_cli_config(
              :artifactory_login => ENV['ARTIFACTORY_LOGIN'],
              :artifactory_password => ENV['ARTIFACTORY_PASSWORD']
            )
          else
            Pod::UI.puts "Please configure ARTIFACTORY_LOGIN and ARTIFACTORY_PASSWORD envirement to use prebuild".red
            exit
          end
          prebuild_all_pods = argv.flag?("all")
          prebuild_targets = argv.option("targets", "").split(",")
          update_cli_config(
            :prebuild_job => true,
            :prebuild_all_pods => prebuild_all_pods,
            :prebuild_config => argv.option("config")
          )
          update_cli_config(:prebuild_targets => prebuild_targets) unless prebuild_all_pods
          @prebuilder = PodPrebuild::CachePrebuilder.new(
            config: prebuild_config,
            repo_update: argv.flag?("repo-update")
          )
        end

        def run
          @prebuilder.run
        end
      end
    end
  end
end
