class Boost < Package

  desc "Boost libraries built without ICU4C"
  homepage "http://www.boost.org"
  url "https://downloads.sourceforge.net/project/boost/boost/${version}/boost_${block}.tar.bz2" do |r| r.version.gsub('.', '_') end

  release version: '1.73.0', crystax_version: 1
  # release version: '1.70.0', crystax_version: 1
  # release version: '1.68.0', crystax_version: 1

  # todo: add versions, like this: python:2.7.*, python:3.*.*
  # depends_on 'python'

  build_options setup_env:            false,
                use_cxx:              true,
                copy_installed_dirs:  [],
                gen_android_mk:       false,
                wrapper_remove_args:  ['-m32', '-m64', '-single_module', '-lpthread', '-lutil'],
                wrapper_replace_args: { '-dynamiclib' => '-shared', '-undefined' => '-u' }

  build_copy 'LICENSE_1_0.txt'
  # todo: build libs list automatically?
  build_libs 'atomic',
             'chrono',
             'container',
             'context',
             'coroutine',
             'date_time',
             'exception',
             'filesystem',
             'graph',
             'iostreams',
             # 'locale',
             'log',
             'log_setup',
             'math_c99',
             'math_c99f',
             'math_c99l',
             'math_tr1',
             'math_tr1f',
             'math_tr1l',
             'prg_exec_monitor',
             'program_options',
             # 'python',
             # 'python3',
             'random',
             'regex',
             'serialization',
             'signals',
             'system',
             'test_exec_monitor',
             'thread',
             'timer',
             'type_erasure',
             'unit_test_framework',
             'wave',
             'wserialization'

  STATIC_ONLY = ['exception', 'test_exec_monitor']

  def initialize(path)
    super path
    @lib_deps = Hash.new([])
  end

  def pre_build(src_dir, release)
    # todo: build bjam here
  end

  def post_build(pkg_dir, release)
    gen_android_mk pkg_dir, release
    nil
  end

  def build_for_abi(abi, _toolchain, release, _host_dep_dirs, _target_dep_dirs, _options)
    args =  [ "--prefix=#{install_dir_for_abi(abi)}",
              "--host=#{host_for_abi(abi)}",
              "--enable-shared",
              "--enable-static",
              "--with-pic",
              "--disable-ld-version-script"
            ]

    arch = Build.arch_for_abi(abi)
    bjam_arch, bjam_abi = bjam_data(arch)

    src_dir = build_dir_for_abi(abi)

    common_args = [ "-d+2",
                    "-j#{num_jobs}",
                    "variant=release",
                    "link=static,shared",
                    "runtime-link=shared",
                    "threading=multi",
                    "target-os=android",
                    "binary-format=elf",
                    "address-model=#{arch.num_bits}",
                    "architecture=#{bjam_arch}",
                    "abi=#{bjam_abi}",
                    "--user-config=#{src_dir}/user-config.jam",
                    "--layout=system",
                    "--without-mpi",
                    "--without-python",
                    without_libs(release, arch).map { |lib| "--without-#{lib}" }
                  ].flatten

    Build::TOOLCHAIN_LIST.each do |toolchain|
      build_env.clear
      stl_name = toolchain.stl_name
      puts "    using C++ standard library: #{stl_name}"

      work_dir = "#{src_dir}/#{stl_name}"
      prefix_dir = "#{work_dir}/install"

      system './bootstrap.sh'

      gen_user_config_jam src_dir

      build_env.clear

      setup_build_env(abi, toolchain)
      @build_env['CXXFLAGS'] += '-fPIC -Wno-long-long'

      # build_env['PATH'] = "#{src_dir}:#{ENV['PATH']}"

      # build without python
      prefix_dir = "#{work_dir}/install"
      build_dir = "#{work_dir}/build"
      gen_project_config_jam src_dir, arch, abi, stl_name, { ver: :none }

      puts "      building boost libraries"
      args = common_args + [' --without-python', "--build-dir=#{build_dir}", "--prefix=#{prefix_dir}"]
      system "#{src_dir}/b2", *args, 'install'

      # # build python libs
      # python_versions.each do |py_ver|
      #   py_dir = "#{Global::HOLD_DIR}/python/#{py_ver}"
      #   py_lib_dir = "#{py_dir}/shared/#{abi}/libs"
      #   ldflags[:after] = "-L#{py_lib_dir} -l#{python_lib_name(py_ver)} " + ldflags[:after]
      #   Build.gen_compiler_wrapper cxx, toolchain.cxx_compiler(arch, abi), toolchain, build_options, cxxflags, ldflags
      #   py_data = { ver:     py_ver,
      #               abi:     python_abi(py_ver),
      #               dir:     py_dir,
      #               lib_dir: py_lib_dir,
      #               inc_dir: "#{py_dir}/include/python"
      #             }
      #   gen_project_config_jam src_dir, arch, abi, stl_name, py_data
      #   args = common_args + ["--build-dir=#{build_dir}-#{py_ver}", "--prefix=#{prefix_dir}-#{py_ver}"]
      #   #
      #   FileUtils.cd("#{src_dir}/libs/python/build") do
      #     puts "      building python library for python #{py_ver}"
      #     system "#{src_dir}/b2", *args, 'install'
      #   end
      #   #
      #   Dir["#{prefix_dir}-#{py_ver}/lib/*"].each { |p| FileUtils.copy_entry p, "#{prefix_dir}/lib/#{File.basename(p)}" }
      # end

      # find and store dependencies for the built libraries
      @lib_deps = Hash.new([])
      Dir["#{prefix_dir}/lib/*.so"].each do |lib|
        name = File.basename(lib).split('.')[0].sub('libboost_', '')
        abi_deps = toolchain.find_so_needs(lib, arch).select { |l| l.start_with? 'libboost_' }.map { |l| l.gsub(/^libboost_/, '') }.sort
        if @lib_deps[name] == []
          @lib_deps[name] = abi_deps
        elsif @lib_deps[name] != abi_deps
          raise "#{lib} has strange dependencies for #{arch.name} and #{toolchain.name}: expected: #{@lib_deps[name]}; got: #{abi_deps}"
        end
      end

      # copy headers if they were not copied yet
      inc_dir = "#{package_dir}/include"
      if !Dir.exists? inc_dir
        FileUtils.mkdir_p package_dir
        FileUtils.cp_r "#{prefix_dir}/include", package_dir
      end
      # copy libs
      libs_dir = "#{package_dir}/libs/#{abi}/#{stl_name}"
      FileUtils.mkdir_p libs_dir
      FileUtils.cp Dir["#{prefix_dir}/lib/*.a"],  libs_dir
      FileUtils.cp Dir["#{prefix_dir}/lib/*.so"], libs_dir
      # run ranlib
      FileUtils.cd(libs_dir) do
        ranlib = toolchain.tool(arch, 'ranlib')
        Dir['*.a'].each { |f| system ranlib, f }
      end
    end
  end

  def bjam_data(arch)
    case arch.name
    when /^arm/               # arm|arm64
      bjam_arch = 'arm'
      bjam_abi = 'aapcs'
    when /^x86/               # x86|x86_64
      bjam_arch = 'x86'
      bjam_abi  = 'sysv'
    when 'mips'
      bjam_arch = 'mips1'
      bjam_abi  = 'o32'
    when 'mips64'
      bjam_arch = 'mips1'
      bjam_abi  = 'o64'
    else
      raise UnsupportedArch.new(arch)
    end

    [bjam_arch, bjam_abi]
  end

  def without_libs(release, arch)
    exclude_libs(release).select { |_, v| v.include? arch.name }.keys
  end

  def exclude_libs(release)
    exclude = {}
    major, minor, _ = release.version.split('.').map { |a| a.to_i }

    # Boost.Context in 1.64.0 and earlier don't support mips64
    # check next versions
    if major == 1 and minor <= 64
      exclude['context'] = ['mips64']
    end

    # Boost.Coroutine depends on Boost.Context
    if archs = exclude['context']
      exclude['coroutine'] = archs
      # Starting from 1.59.0, there is Boost.Coroutine2 library, which depends on Boost.Context too
      if major == 1 and minor >= 59
        exclude['coroutine2'] = archs
      end
    end

    exclude
  end

  def gen_project_config_jam(dir, arch, abi, stl_name, python_data)
    File.open("#{dir}/project-config.jam", 'w') do |f|
      f.puts "import option ;"
      f.puts "import feature ;"
      f.puts "import os ;"

      f.puts "cxxflags = [ os.environ CXXFLAGS ] ;"
      f.puts "linkflags = [ os.environ LDFLAGS ] ;"
      f.puts "linkflags += [ os.environ LIBS ] ;"

      unless python_data[:ver] == :none
        #f.puts "import python ;" unless python_data[:ver] =~ /^2\..*/
        f.puts "using python : #{python_data[:abi]} : #{python_data[:dir]} : #{python_data[:inc_dir]} : #{python_data[:lib_dir]} : <target-os>android ;"
      end
      case stl_name
      when /^gnu-/
        f.puts "using gcc : #{arch.name} : #{build_env['CXX']} : <archiver>\"#{build_env['AR']}\" <ranlib>\"#{build_env['RANLIB']}\" <cxxflags>\"-std=c++14 $(cxxflags) \" <linkflags>$(linkflags) ;"
        f.puts "project : default-build <toolset>gcc ;"
      when /^llvm/
        f.puts "using clang-linux : #{arch.name} : #{build_env['CXX']} : <archiver>\"#{build_env['AR']}\" <ranlib>\"#{build_env['RANLIB']}\" <cxxflags>\"-std=c++14 $(cxxflags) \" <linkflags>$(linkflags) ;"
        f.puts "project : default-build <toolset>clang-linux ;"
      else
        raise "unsupported C++ standard library: #{stl_name}"
      end
      f.puts "libraries = ;"
      f.puts "option.set keep-going : false ;"
    end
  end

  def gen_user_config_jam(dir)
    FileUtils.touch "#{dir}/user-config.jam"
    # 'using mpi' break build on linux because build system
    # tries to use locally found (system) mpi libs
    #File.open("#{dir}/user-config.jam", 'w') { |f| f.puts "using mpi ;" }
  end

  def gen_android_mk(pkg_dir, release)
    exclude = exclude_libs(release)

    File.open("#{pkg_dir}/Android.mk", "w") do |f|
      f.puts Build::COPYRIGHT_STR
      f.puts ''
      f.puts 'LOCAL_PATH := $(call my-dir)'
      f.puts ''
      f.puts 'ifeq (,$(filter gnustl_% c++_%,$(APP_STL)))'
      f.puts '$(error $(strip \\'
      f.puts '    We do not support APP_STL \'$(APP_STL)\' for Boost libraries! \\'
      f.puts '    Please use either "gnustl_shared", "gnustl_static", "c++_shared" or "c++_static". \\'
      f.puts '))'
      f.puts 'endif'
      f.puts ''
      @lib_deps.each do |name, deps|
        exclude_flag = false
        if archs = exclude[name]
          exclude_flag = true
          f.puts "ifeq (,$(filter #{archs.join(' ')},$(TARGET_ARCH_ABI)))"
        end
        ## Disable config for static libraries
        # f.puts 'include $(CLEAR_VARS)'
        # f.puts "LOCAL_MODULE := boost_#{name}_static"
        # f.puts "LOCAL_SRC_FILES := libs/$(TARGET_ARCH_ABI)/llvm/libboost_#{name}.a"
        # f.puts 'LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/include'
        # f.puts 'ifneq (,$(filter clang%,$(NDK_TOOLCHAIN_VERSION)))'
        # f.puts 'LOCAL_EXPORT_LDLIBS := -latomic'
        # f.puts 'endif'
        # @lib_deps[name].each do |dep|
        #   f.puts "LOCAL_STATIC_LIBRARIES += boost_#{dep}_static"
        # end
        # f.puts 'include $(PREBUILT_STATIC_LIBRARY)'
        # f.puts ''
        # unless STATIC_ONLY.include? name
        f.puts 'include $(CLEAR_VARS)'
        f.puts "LOCAL_MODULE := boost_#{name}_shared"
        f.puts "LOCAL_SRC_FILES := libs/$(TARGET_ARCH_ABI)/llvm/libboost_#{name}.so"
        f.puts 'LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/include'
        f.puts 'ifneq (,$(filter clang%,$(NDK_TOOLCHAIN_VERSION)))'
        f.puts 'LOCAL_EXPORT_LDLIBS := -latomic'
        f.puts 'endif'
        deps.each do |dep|
          f.puts "LOCAL_SHARED_LIBRARIES += boost_#{dep}_shared"
        end
        f.puts 'include $(PREBUILT_SHARED_LIBRARY)'
        # end
        if exclude_flag
          f.puts 'endif'
          exclude_flag = false
        end
        # todo: do not output empty lines for the last element
        f.puts ''
        f.puts ''
      end
    end
  end

  def python_versions
    # todo: get last versions for 2.* and 3.*
    ['2.7.11', '3.5.1']
  end

  def python_lib_name(ver)
    abi = python_abi(ver)
    case abi
    when /^2\..*/
      "python#{abi}"
    when /^3\..*/
      "python#{abi}m"
    else
      raise "unsupported python version: #{ver}"
    end
  end

  def python_abi(ver)
    v = ver.split('.')
    "#{v[0]}.#{v[1]}"
  end

  def sonames_translation_table(release)
    v = release.version
    {
      "libboost_atomic.so.#{v}"                => "libboost_atomic",
      "libboost_chrono.so.#{v}"                => "libboost_chrono",
      "libboost_container.so.#{v}"             => "libboost_container",
      "libboost_context.so.#{v}"               => "libboost_context",
      "libboost_contract.so.#{v}"              => "libboost_contract",
      "libboost_coroutine.so.#{v}"             => "libboost_coroutine",
      "libboost_date_time.so.#{v}"             => "libboost_date_time",
      "libboost_filesystem.so.#{v}"            => "libboost_filesystem",
      "libboost_graph.so.#{v}"                 => "libboost_graph",
      "libboost_graph_parallel.so.#{v}"        => "libboost_graph_parallel",
      "libboost_iostreams.so.#{v}"             => "libboost_iostreams",
      "libboost_locale.so.#{v}"                => "libboost_locale",
      "libboost_log.so.#{v}"                   => "libboost_log",
      "libboost_log_setup.so.#{v}"             => "libboost_log_setup",
      "libboost_math_c99.so.#{v}"              => "libboost_math_c99",
      "libboost_math_c99f.so.#{v}"             => "libboost_math_c99f",
      "libboost_math_c99l.so.#{v}"             => "libboost_math_c99l",
      "libboost_math_tr1.so.#{v}"              => "libboost_math_tr1",
      "libboost_math_tr1f.so.#{v}"             => "libboost_math_tr1f",
      "libboost_math_tr1l.so.#{v}"             => "libboost_math_tr1l",
      "libboost_mpi_python-py27.so.#{v}"       => "libboost_mpi_python-py27",
      "libboost_mpi_python-py34.so.#{v}"       => "libboost_mpi_python-py34",
      "libboost_mpi_python.so.#{v}"            => "libboost_mpi_python",
      "libboost_mpi.so.#{v}"                   => "libboost_mpi",
      "libboost_prg_exec_monitor.so.#{v}"      => "libboost_prg_exec_monitor",
      "libboost_program_options.so.#{v}"       => "libboost_program_options",
      "libboost_python-py27.so.#{v}"           => "libboost_python-py27",
      "libboost_python-py34.so.#{v}"           => "libboost_python-py34",
      "libboost_python.so.#{v}"                => "libboost_python",
      "libboost_random.so.#{v}"                => "libboost_random",
      "libboost_regex.so.#{v}"                 => "libboost_regex",
      "libboost_serialization.so.#{v}"         => "libboost_serialization",
      "libboost_signals.so.#{v}"               => "libboost_signals",
      "libboost_stacktrace_basic.so.#{v}"      => "libboost_stacktrace_basic",
      "libboost_stacktrace_noop.so.#{v}"       => "libboost_stacktrace_noop",
      "libboost_system.so.#{v}"                => "libboost_system",
      "libboost_thread.so.#{v}"                => "libboost_thread",
      "libboost_timer.so.#{v}"                 => "libboost_timer",
      "libboost_type_erasure.so.#{v}"          => "libboost_type_erasure",
      "libboost_unit_test_framework.so.#{v}"   => "libboost_unit_test_framework",
      "libboost_wave.so.#{v}"                  => "libboost_wave",
      "libboost_wserialization.so.#{v}"        => "libboost_wserialization"
    }
  end

end
