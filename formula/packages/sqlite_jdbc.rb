class SqliteJdbc < Package

  desc 'SqliteJdbc'
  homepage 'hhttps://github.com/xerial/sqlite-jdb'
  url 'git://github.com/xerial/sqlite-jdbc.git|git_commit:d95842040de3c4c6f15cfeab5b6ea90787690d42'

  release version: '3.25.2', crystax_version: 1

  depends_on 'sqlite'

  def build_for_abi(abi, _toolchain, _release, _host_dep_dirs, target_dep_dirs, _options)
    install_dir = install_dir_for_abi(abi)

    src_dir = build_dir_for_abi(abi)

    Build::TOOLCHAIN_LIST.each do |toolchain|
      build_env.clear
      stl_name = toolchain.stl_name
      puts "    using C++ standard library: #{stl_name}"

      work_dir = "#{src_dir}/#{stl_name}"
      prefix_dir = "#{work_dir}/install"

      FileUtils.mkdir_p "#{install_dir}/lib"
      FileUtils.mkdir_p "#{install_dir}/include"

      host_tc_dir = "#{work_dir}/"
      FileUtils.mkdir_p host_tc_dir
      host_cc = "#{host_tc_dir}/gcc"
      Build.gen_host_compiler_wrapper host_cc, 'gcc'

      setup_build_env(abi, toolchain)
      @build_env['LINKFLAGS'] = [
        "-llog",
      ].join(' ')

      system 'make', 'clean-native', 'native', "CROSS_PREFIX=#{work_dir}/",
             'OS_NAME=Linux', 'OS_ARCH=android-arm', '-j', num_jobs

      libs_dir = "#{package_dir}/libs/#{abi}/#{stl_name}"
      FileUtils.mkdir_p libs_dir
      FileUtils.cp Dir["/tmp/libsqlitejdbc.so"], libs_dir
    end
  end
end