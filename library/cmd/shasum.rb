require_relative '../exceptions.rb'
require_relative '../release.rb'
require_relative '../formulary.rb'
require_relative '../platform.rb'
require_relative 'shasum_options.rb'


module Crew

  def self.shasum(args)
    options, args = ShasumOptions.parse_args(args)

    Formulary.new.select(args).each do |formula|
      formula.releases.each do |release|
        platforms = (formula.namespace == :target) ? ['android'] : options.platforms
        platforms.each do |platform_name|
          # an ugly special case for windows toolbox
          # it seems that everything related to windows is ugly
          next if formula.name == 'toolbox' and not platform_name.start_with?('windows')
          #
          archive = formula.cache_file(release, platform_name)
          print "#{formula.fqn} #{release}"
          print (formula.namespace == :target) ? ': ' : " #{platform_name}: "
          if not File.exist? archive
            puts "archive not found: #{archive}"
          else
            sum = Digest::SHA256.hexdigest(File.read(archive, mode: "rb"))
            if sum == formula.read_shasum(release, platform_name)
              puts "OK"
            elsif options.update?
              formula.update_shasum release, platform_name
              puts "updated"
            else
              puts "BAD"
            end
          end
        end
      end
    end
  end
end
