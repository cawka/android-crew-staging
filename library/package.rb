require 'fileutils'
require_relative 'release.rb'
require_relative 'build.rb'
require_relative 'deb.rb'
require_relative 'cmd/build_options.rb'
require_relative 'target_base.rb'


class Package < TargetBase

  SRC_DIR_BASENAME = 'src'

  DEF_BUILD_OPTIONS = { source_archive_without_top_dir: false,
                        build_outside_source_tree:      false,
                        c_wrapper:                      'cc',
                        sysroot_in_cflags:              true,
                        cflags_in_c_wrapper:            false,
                        ldflags_in_c_wrapper:           false,
                        use_cxx:                        false,
                        cxx_wrapper:                    'c++',
                        setup_env:                      true,
                        use_standalone_toolchain:       false,
                        use_static_libcrystax:          false,
                        copy_installed_dirs:            ['lib', 'include'],
                        check_sonames:                  true,
                        gen_android_mk:                 true,
                        wrapper_translate_sonames:      Hash.new,
                        wrapper_fix_stl:                false,
                        wrapper_filter_out:             nil,
                        wrapper_remove_args:            Array.new,
                        wrapper_replace_args:           Hash.new
                      }.freeze

  attr_reader :pre_build_result, :post_build_result

  def has_home_directory?
    true
  end

  def home_directory
    File.join(Global::HOLD_DIR, file_name)
  end

  def release_directory(release)
    File.join(home_directory, release.version)
  end

  def properties_directory(release)
    release_directory release
  end

  def install_archive(release, archive, _platform_name = nil)
    rel_dir = release_directory(release)
    FileUtils.rm_rf binary_files(rel_dir)
    Utils.unpack archive, rel_dir

    # todo:
    #update_root_android_mk release

    prop = get_properties(rel_dir)
    prop[:installed] = true
    prop[:source_installed] = release.source_installed?
    prop[:installed_crystax_version] = release.crystax_version
    save_properties prop, rel_dir

    release.installed = release.crystax_version
  end

  def uninstall(release)
    puts "removing #{name}:#{release.version}"
    rel_dir = release_directory(release)
    if not release.source_installed?
      FileUtils.rm_rf rel_dir
    else
      prop = get_properties(rel_dir)
      FileUtils.rm_rf binary_files(rel_dir)
      prop[:installed] = false
      save_properties prop, rel_dir
    end
    release.installed = false
  end

  def source_installed?(release = Release.new)
    releases.any? { |r| r.match?(release) and r.source_installed? }
  end

  def install_source(release)
    puts "installing source code for #{name}:#{release}"
    rel_dir = release_directory(release)
    prop = get_properties(rel_dir)
    if prop[:installed_crystax_version] == nil
      prop[:installed_crystax_version] = release.crystax_version
      FileUtils.mkdir_p rel_dir
    end

    prepare_source_code release, rel_dir, SRC_DIR_BASENAME, '='

    release.source_installed = release.crystax_version
    prop[:source_installed] = true
    save_properties prop, rel_dir
  end

  def uninstall_source(release)
    puts "uninstalling source code for #{name}:#{release.version}"
    rel_dir = release_directory(release)
    if not release.installed?
      FileUtils.rm_rf rel_dir
    else
      prop = get_properties(rel_dir)
      FileUtils.rm_r source_directory(release)
      prop[:source_installed] = false
      save_properties prop, rel_dir
    end
    release.source_installed = false
  end

  def build(release, options, host_dep_dirs, target_dep_dirs)
    base_dir = build_base_dir
    FileUtils.rm_rf base_dir
    FileUtils.mkdir_p base_dir
    @log_file = build_log_file

    arch_list = Build.abis_to_arch_list(options.abis)
    build_log_puts "Building #{name} #{release} for architectures: #{arch_list.map{|a| a.name}.join(' ')}"

    src_dir = source_directory(release)
    @num_jobs = options.num_jobs

    build_env.clear
    build_options[:setup_env] = false if build_options[:use_standalone_toolchain]
    raise "static libcrystax can be used only with standalone toolchain" if build_options[:use_static_libcrystax] and not build_options[:use_standalone_toolchain]

    if self.respond_to? :pre_build
      build_log_print "= executing pre build step: "
      @pre_build_result = pre_build(src_dir, release)
      build_log_puts @pre_build_result ? @pre_build_result : 'OK'
    end

    toolchain = Build::DEFAULT_TOOLCHAIN
    build_options[:wrapper_translate_sonames] = sonames_translation_table(release) if self.respond_to? :sonames_translation_table

    FileUtils.mkdir_p package_dir
    arch_list.each do |arch|
      build_log_puts "= building for architecture: #{arch.name}"
      if build_options[:use_standalone_toolchain]
        st_packages = target_dep_dirs.keys
        st_base_dir = "#{build_base_dir}/#{arch.name}-toolchain"
        build_log_puts "  making standalone toolchain with packages: #{st_packages}"
        toolchain = Toolchain::Standalone.new(arch, st_base_dir, Toolchain::DEFAULT_GCC, Toolchain::DEFAULT_LLVM, st_packages, self)
        toolchain.remove_dynamic_libcrystax if build_options[:use_static_libcrystax]
      end
      arch.abis_to_build.each do |abi|
        build_log_puts "  building for abi: #{abi}"
        FileUtils.mkdir_p base_dir_for_abi(abi)
        build_dir = build_dir_for_abi(abi)
        #
        if build_options[:build_outside_source_tree]
          FileUtils.mkdir_p build_dir
        else
          FileUtils.cp_r "#{src_dir}/.", build_dir
          # without this code some packages (f.e. cpio) could fail to build
          timestamp = Time.new.localtime.strftime('%Y%m%d%H%M.%S')
          Dir["#{build_dir}/**/*"].each { |f| Utils::run_command('touch', '-t', timestamp, f) }
        end
        #
        setup_build_env abi, toolchain if build_options[:setup_env]
        FileUtils.cd(build_dir) { build_for_abi abi, toolchain, release, host_dep_dirs, target_dep_dirs, options }
        Build.check_sonames install_dir_for_abi(abi), arch if build_options[:check_sonames]
        copy_installed_files abi
        FileUtils.rm_rf base_dir_for_abi(abi) unless options.no_clean?
      end
    end

    Build.gen_android_mk "#{package_dir}/Android.mk", build_libs, build_options if build_options[:gen_android_mk]

    if self.respond_to? :post_build
      build_log_print "= executing post build step: "
      @post_build_result = post_build(package_dir, release)
      build_log_puts @post_build_result ? @post_build_result : 'OK'
    end

    build_copy.each { |f| FileUtils.cp "#{src_dir}/#{f}", package_dir }
    copy_tests

    if options.build_only?
      build_log_puts "Build only, no packaging and installing"
    else
      # pack archive and copy into cache dir
      archive = cache_file(release)
      build_log_puts "Creating archive file #{archive}"
      Utils.pack(archive, package_dir)

      update_shasum release if options.update_shasum?

      # install into packages (and update props if any)
      # we do not use Formula's install method here to bypass SHA256 sum checks,
      # build command is intended for a developers
      if options.install?
        build_log_puts "Unpacking archive into #{release_directory(release)}"
        install_archive release, archive
      end
    end

    if options.no_clean?
      build_log_puts "No cleanup, for build artifacts see #{base_dir}"
    else
      FileUtils.rm_rf base_dir
    end
  end

  def source_directory(release)
    "#{release_directory(release)}/#{SRC_DIR_BASENAME}"
  end

  def setup_build_env(abi, toolchain)
    cflags  = toolchain.cflags(abi)
    ldflags = toolchain.ldflags(abi)

    arch = Build.arch_for_abi(abi)
    c_comp = toolchain.c_compiler(arch, abi)

    # c_comp += " --sysroot=#{Build.sysroot_libs(abi)}"
    # c_comp += " -isysroot #{Build.sysroot_inc(abi)}"
    # c_comp += " -isystem #{Build.sysroot_inc(abi)}/usr/include"
    # c_comp += " -isystem #{Build.sysroot_inc_arch(abi)}"

    if not build_options[:c_wrapper]
      cc = c_comp
    else
      cc = build_options[:c_wrapper] == true ? toolchain.c_compiler_name : build_options[:c_wrapper]
      cc = "#{build_dir_for_abi(abi)}/#{cc}"
      c_comp += ' ' + cflags if build_options[:cflags_in_c_wrapper]
      ldflags_wrapper_arg = build_options[:ldflags_in_c_wrapper] ? { before: ldflags, after: '' } : nil
      Build.gen_compiler_wrapper cc, c_comp, toolchain, build_options, '', ldflags_wrapper_arg
    end

    @build_env = {'LC_MESSAGES' => 'C',
                  'CC'          => cc,
                  'CPP'         => "#{cc} #{cflags} -E",
                  'AR'          => toolchain.tool(arch, 'ar'),
                  'NM'          => toolchain.tool(arch, 'nm'),
                  'AS'          => toolchain.tool(arch, 'as'),
                  'LD'          => toolchain.tool(arch, 'ld'),
                  'RANLIB'      => toolchain.tool(arch, 'ranlib'),
                  'READELF'     => toolchain.tool(arch, 'readelf'),
                  'STRIP'       => toolchain.tool(arch, 'strip'),
                  'CFLAGS'      => cflags,
                  'LDFLAGS'     => ldflags
                 }

    if build_options[:use_cxx]
      cxx_comp = toolchain.cxx_compiler(arch, abi)

      # cxx_comp += " --sysroot=#{Build.sysroot_libs(abi)}"
      # cxx_comp += " -isysroot #{Build.sysroot_inc(abi)}"
      # cxx_comp += " -isystem #{Build.sysroot_inc(abi)}/usr/include"
      # cxx_comp += " -isystem #{Build.sysroot_inc_arch(abi)}"

      # cxxflags = toolchain.search_path_for_stl_includes(abi)

      ldflags_wrapper_arg = { before: ldflags, #  + " #{toolchain.search_path_for_stl_libs(abi)}",
                              after:  "-l#{toolchain.stl_lib_name}_shared" }

      cxx = build_options[:cxx_wrapper] == true ? toolchain.cxx_compiler_name : build_options[:cxx_wrapper]
      cxx = "#{build_dir_for_abi(abi)}/#{cxx}"
      Build.gen_compiler_wrapper cxx, cxx_comp, toolchain, build_options, '', ldflags_wrapper_arg

      @build_env['CXX']      = cxx
      @build_env['CXXCPP']   = "#{cxx} #{cflags} -E"
      @build_env['CXXFLAGS'] = cflags

      puts @build_env
    end
  end

  def copy_installed_files(abi)
    dirs = build_options[:copy_installed_dirs]
    install_dir = install_dir_for_abi(abi)
    FileUtils.mkdir_p package_dir
    dirs.each do |dir|
      case dir
      when 'bin', 'libexec', 'sbin'
        FileUtils.mkdir_p "#{package_dir}/#{dir}"
        FileUtils.cp_r "#{install_dir}/#{dir}", "#{package_dir}/#{dir}/#{abi}", preserve: true
      when 'etc', 'include', 'share', 'var'
        # copy files if they were not copied yet
        FileUtils.cp_r "#{install_dir}/#{dir}", package_dir, preserve: true unless Dir.exists? "#{package_dir}/#{dir}"
      when 'lib'
        # copy libs
        FileUtils.mkdir_p "#{package_dir}/libs"
        FileUtils.cp_r "#{install_dir}/lib", "#{package_dir}/libs/#{abi}", preserve: true
      else
        raise "unsupported installed dir name: #{dir}"
      end
    end
  end

  def copy_tests
    src_tests_dir = "#{Build::VENDOR_TESTS_DIR}/#{file_name}"
    if Dir.exists? src_tests_dir
      dst_tests_dir = "#{package_dir}/tests"
      FileUtils.mkdir dst_tests_dir
      FileUtils.cp_r "#{src_tests_dir}/.", "#{dst_tests_dir}/"
    end
  end

  class << self

    def build_copy(*args)
      if args.size == 0
        @build_copy ? @build_copy : []
      else
        @build_copy = args
      end
    end

    def build_libs(*args)
      if args.size == 0
        @build_libs ? @build_libs : [ name ]
      else
        @build_libs = args
      end
    end
  end

  def build_copy
    self.class.build_copy
  end

  def build_libs
    self.class.build_libs
  end

  def copy_to_standalone_toolchain(release, arch, target_include_dir, target_lib_dir, _options)
    make_target_lib_dirs(arch, target_lib_dir)

    release_dir = release_directory(release)
    src_lib_dir = "#{release_dir}/libs"

    FileUtils.cp_r Dir["#{release_dir}/include/*"], target_include_dir

    case arch.name
    when 'arm'
      # todo: it seems clang can't find required libs so we copy armveabi-v7a libs to a place where armeabi libs were
      #       gcc works fine without those copies
      FileUtils.cp_r toolchain_libs(src_lib_dir, 'armeabi-v7a'),      "#{target_lib_dir}/lib/"
      FileUtils.cp_r toolchain_libs(src_lib_dir, 'armeabi-v7a'),      "#{target_lib_dir}/lib/thumb/"
      #
      FileUtils.cp_r toolchain_libs(src_lib_dir, 'armeabi-v7a'),      "#{target_lib_dir}/lib/armv7-a/"
      FileUtils.cp_r toolchain_libs(src_lib_dir, 'armeabi-v7a'),      "#{target_lib_dir}/lib/armv7-a/thumb/"
    when 'mips64', 'x86_64'
      FileUtils.cp_r toolchain_libs(src_lib_dir, arch.abis[0]), "#{target_lib_dir}/lib64/"
    else
      FileUtils.cp_r toolchain_libs(src_lib_dir, arch.abis[0]), "#{target_lib_dir}/lib/"
    end
  end

  def toolchain_libs(dir, abi)
    Dir["#{dir}/#{abi}/*"]
  end

  # some libraries use pthread_cancel to check whether pthread is in use
  # since we do not have pthread_cancel (at least right now) we must handle the issue by editing config.h
  def set_pthread_in_use_detection_hard(config_h_file)
    replace_lines_in_file(config_h_file) do |line|
      if line == '/* #undef PTHREAD_IN_USE_DETECTION_HARD */'
        '#define PTHREAD_IN_USE_DETECTION_HARD 1'
      else
        line
      end
    end
  end

  def clean_install_dir(abi, *types)
    FileUtils.cd(install_dir_for_abi(abi)) do
      types.each do |type|
        case type
        when :lib
          FileUtils.rm_rf ['lib/pkgconfig'] + Dir['lib/**/*.la']
          Dir['lib/**/*.so', 'lib/**/*.so.*'].each { |f| FileUtils.rm f if File.symlink?(f) }
        else
          raise "unknown type to cleanup: #{type}"
        end
      end
    end
  end

  def target_dep_include_dir(dir)
    "-I#{dir}/include"
  end

  def target_dep_lib_dir(dir, abi)
    "-L#{dir}/libs/#{abi}"
  end

  def target_dep_all_include_dirs(dirs)
    dirs.values.inject('') { |acc, dir| "#{acc} #{target_dep_include_dir(dir)}" }
  end

  def target_dep_all_lib_dirs(dirs, abi)
    dirs.values.inject('') { |acc, dir| "#{acc} #{target_dep_lib_dir(dir, abi)}" }
  end

  private

  def binary_files(rel_dir)
    Dir["#{rel_dir}/*"].select{ |a| File.basename(a) != SRC_DIR_BASENAME }
  end

  def package_dir
    "#{build_base_dir}/package"
  end

  def base_dir_for_abi(abi)
    "#{build_base_dir}/#{abi}"
  end

  def build_dir_for_abi(abi)
    "#{base_dir_for_abi(abi)}/build"
  end

  def install_dir_for_abi(abi)
    "#{base_dir_for_abi(abi)}/install"
  end

  def host_for_abi(abi)
    Build.arch_for_abi(abi).host
  end
end
