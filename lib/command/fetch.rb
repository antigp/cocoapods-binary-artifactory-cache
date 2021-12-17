require_relative "executor/fetcher"
require 'io/console'

module Pod
  class Command
    class Binary < Command
      class Fetch < Binary
        self.arguments = [CLAide::Argument.new("CACHE-BRANCH", false)]
        def initialize(argv)
          super
          unless ENV['ARTIFACTORY_LOGIN'].nil? && ENV['ARTIFACTORY_PASSWORD'].nil?
            update_cli_config(
              :artifactory_login => ENV['CI_ARTIFACTORY_LOGIN'],
              :artifactory_password => ENV['ARTIFACTORY_PASSWORD']
            )
          else
            Pod::UI.puts "Enter Artifactory login:"
            login = IO::console.gets.strip
            Pod::UI.puts "Enter Artifactory password:"
            password = IO::console.getpass
            update_cli_config(
              :artifactory_login => login,
              :artifactory_password => password
            )
          end
          update_cli_config(
            :fetch_job => true
          )
          @fetcher = PodPrebuild::CacheFetcher.new(
            config: prebuild_config,
          )
        end

        def run
          @fetcher.run
        end
      end
    end
  end
end
