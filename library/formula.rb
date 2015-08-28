require 'digest'
require_relative 'extend/module.rb'
require_relative 'utils.rb'

class Formula

  def self.package_version(release)
    "#{release[:version]}_#{release[:crystax_version]}"
  end

  def self.split_package_version(pkgver)
    r = pkgver.split('_')
    raise "bad package version string: #{pkgver}" if r.size < 2
    cxver = r.pop.to_i
    ver = r.join('_')
    {version: ver, crystax_version: cxver}
  end

  # The name of this {Formula}.
  # e.g. `this-formula`
  attr_reader :name

  # The full path to this {Formula}.
  # e.g. `formula/this-formula.rb`
  attr_reader :path

  def initialize(name, path)
    @name = name
    @path = path
  end

  def desc
    self.class.desc
  end

  def homepage
    self.class.homepage
  end

  def releases
    self.class.releases
  end

  def dependencies
    self.class.dependencies ? self.class.dependencies : []
  end

  def full_dependencies(hold, release)
    result = []
    size = 0 # todo: set to the size of the required release: {version:, crystax_version:}
    deps = dependencies

    while deps.size > 0
      n = deps.first.name
      if hold.installed?(n)
        deps = deps.slice(1, deps.size)
        next
      end
      if !result.include?(n)
        result << n
        # todo: update size
      end
      f = Formulary.factory(n)
      deps = f.dependencies + deps.slice(1, deps.size)
    end

    [result, size]
  end

  def cache_file(release)
    File.join(Global::CACHE_DIR, filename(release))
  end

  def install(r = {})
    release = find_release r
    file = filename release
    cachepath = File.join(Global::CACHE_DIR, file)

    if File.exists? cachepath
      puts "using cached file #{file}"
    else
      url = "#{Global::DOWNLOAD_BASE}/#{file}"
      puts "downloading #{url}"
      Utils.download(url, cachepath)
    end

    puts "checking integrity of the downloaded file #{file}"
    if Digest::SHA256.hexdigest(File.read(cachepath, mode: "rb")) != release[:sha256]
      raise "bad SHA256 sum of the downloaded file #{cachepath}"
    end

    Hold.install_release(name, release, cachepath)
    # todo: remove downloaded file in case of any exception; on not?
  end

  def latest_version
    releases.last[:version]
  end

  def exclude_latest(versions)
    lver = nil
    lind = -1
    versions.each do |v|
      ind = find_release_index_by_version(v)
      if ind > lind
        lind = ind
        lver = v
      end
    end
    versions.delete(lver)
    versions
  end

  class Dependency

    def initialize(name, options)
      @options = options
      @options[:name] = name
    end

    def name
      @options[:name]
    end
  end

  class << self

    attr_rw :desc, :homepage, :space_reqired

    attr_reader :releases, :dependencies

    def release(r)
      @releases = [] if !@releases
      check_required_keys(r)
      # NB: release are sorted in the order they're included into formula
      @releases << r
    end

    def depends_on(name, options = {})
      @dependencies = [] if !@dependencies
      @dependencies << Dependency.new(name, options)
    end

    private

    def check_required_keys(r)
      raise ":version key not present in the release"         unless r.has_key?(:version)
      raise ":crystax_version key not present in the release" unless r.has_key?(:crystax_version)
      raise ":sha256 key not present in the release"          unless r.has_key?(:sha256)
    end
  end

  def to_info(room)
    info = "Name:        #{name}\n"     \
           "Homepage:    #{homepage}\n" \
           "Description: #{desc}\n"     \
           "Type:        #{type}\n"     \
           "Releases:\n"
    releases.each do |r|
      installed = room.installed?(name, r) ? "installed" : ""
      info += "  #{r[:version]} #{r[:crystax_version]}  #{installed}\n"
    end
    if dependencies.size > 0
      puts "Dependencies:"
      dependencies.each.with_index do |d, ind|
        installed = room.installed?(d.name) ? " (*)" : ""
        info += "  #{d.name}#{installed}"
      end
    end
    info
  end

  def find_release(r = {})
    if !r[:version]
      rel = releases.last
    elsif !r[:crystax_version]
      rel = (releases.select {|e| e[:version] == r[:version]}).last
      raise "#{name} has no release with version #{r[:version]}" unless rel
    else
      rel = (releases.select {|e| e[:version] == r[:version] and e[:crystax_version] == r[:crystax_version]}).last
      raise "#{name} has no release #{r[:version]}:#{r[:crystax_version]}" unless rel
    end
    rel
  end

  private

  def filename(release)
    "#{name}-#{Formula.package_version(release)}.7z"
  end

  def find_release_index_by_version(version)
    releases.each.with_index do |rel, ind|
      if rel[:version] == version
        return ind
      end
    end
    raise "formula #{name} has no release with version #{version}"
  end
end
