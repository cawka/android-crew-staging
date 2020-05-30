class Openssl < Package

  desc "Cryptography and SSL/TLS Toolkit"
  homepage "https://openssl.org/"
  url 'https://openssl.org/source/openssl-${version}.tar.gz'

  # release version: '1.0.2o', crystax_version: 1
  # release version: '1.1.0h', crystax_version: 1
  release version: '1.1.1g', crystax_version: 2
  # release version: '1.1.1-pre8', crystax_version: 1

  build_options copy_installed_dirs:  ['bin', 'include', 'lib']

  build_copy 'LICENSE'
  build_libs 'libcrypto', 'libssl'

  def build_for_abi(abi, toolchain, release, _host_dep_dirs, _target_dep_dirs, options)
    ssl_ver = release.major_point_minor
    install_dir = install_dir_for_abi(abi)
    build_env['CFLAGS'] << ' -DOPENSSL_NO_DEPRECATED'


    args = ["--prefix=#{install_dir}",
            "no-asm",
            "shared",
            "zlib-dynamic",
            target(abi)
            # build_env['CFLAGS'],
            # build_env['LDFLAGS'],
           ]

    # 1.1.* uses engine/name for engine sonames
    # todo: check if we can safely remove 'engine/' prefixes from engine's sonames
    self.build_options[:check_sonames] = false if ssl_ver == '1.1'

    # parallel build seems to be broken on darwin
    # lets try parallell build with 1.1.*
    self.num_jobs = 1 if ssl_ver == '1.0' and Global::OS == 'darwin' and options.num_jobs_default?

    system './Configure',  *args

    # 1.1* have no gost engine
    fix_ccgost_makefile build_dir_for_abi(abi), toolchain.ldflags(abi) if ssl_ver == '1.0'
    fix_make_depend if release.version == '1.0.2o'

    system 'make', 'depend'
    system 'make', '-j', num_jobs
    system "make install"

    # prepare installed files for packaging
    FileUtils.rm_rf File.join("#{install_dir}/lib/pkgconfig")
    FileUtils.cd("#{install_dir}/lib") do
      FileUtils.mv "engines-#{ssl_ver}", 'engines' if ssl_ver == '1.1'
      build_libs.each do |f|
        FileUtils.rm "#{f}.so"
        # 1.0.* uses 1.0.0 suffix for lib names
        suffix =  (ssl_ver == '1.0') ? "#{ssl_ver}.0" : ssl_ver
        FileUtils.mv "#{f}.so.#{suffix}", "#{f}.so"
      end
    end
  end

  def target(abi)
    case abi
    when 'x86'       then 'linux-elf'
    when 'x86_64'    then 'linux-x86_64'
    when /^armeabi/  then 'linux-armv4'
    when 'arm64-v8a' then 'linux-aarch64'
    when 'mips'      then 'linux-generic32'   # Looks like asm code in OpenSSL doesn't support MIPS32r6
    when 'mips64'    then 'linux-generic64'   # Looks like asm code in OpenSSL doesn't support MIPS64r6
    else
      raise "Unsupported abi #{abi}"
    end
  end

  def fix_ccgost_makefile(build_dir, ldflags)
    makefile = File.join(build_dir, 'engines', 'ccgost', 'Makefile')
    lines = []
    replaced = false
    File.foreach(makefile) do |l|
      if not l.include?('LIBDEPS=\'-L$(TOP) -lcrypto')
        lines << l
      else
        ldflags = ldflags.gsub(' -pie', '')
        lines << l.gsub('LIBDEPS=\'', "LIBDEPS=\'#{ldflags} ")
        replaced = true
      end
    end

    raise "not found required line in #{makefile}" unless replaced

    File.open(makefile, 'w') { |f| f.puts lines }
  end

  def fix_make_depend
    replaced = replace_lines_in_file('Makefile') do |line|
      if line =~ /^MAKEDEPPROG= .*\/cc/
        'MAKEDEPPROG= makedepend'
      else
        line
      end
    end
    raise "fail to fix make depend" unless replaced == 1
  end


  def sonames_translation_table(release)
    r = release.version.split('.')
    v = "#{r[0]}.#{r[1]}"
    if release.version =~ /^1\.0/
      { "libcrypto.so.#{v}.0" => 'libcrypto',
        "libssl.so.#{v}.0"    => 'libssl'
      }
    else
      { "libcrypto.so.#{v}" => 'libcrypto',
        "libssl.so.#{v}"    => 'libssl'
      }
    end
  end
end
