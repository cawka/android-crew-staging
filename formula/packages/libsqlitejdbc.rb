class Libsqlitejdbc < Package

  desc 'SqliteJdbc'
  homepage 'https://github.com/xerial/sqlite-jdbc'
  url 'https://github.com/xerial/sqlite-jdbc.git|git_commit:d95842040de3c4c6f15cfeab5b6ea90787690d42'

  release version: '3.25.2.1', crystax_version: 1

  build_options gen_android_mk: false,
                check_sonames: false

  depends_on 'sqlite'

  def target(abi)
    case abi
    when 'x86'       then 'x86'
    when 'x86_64'    then 'x86_64'
    when /^armeabi/  then 'android-arm'
    when 'arm64-v8a' then 'aarch64'
    else
      raise "Unsupported abi #{abi}"
    end
  end

  def post_build(pkg_dir, release)
    gen_android_mk pkg_dir, release
    nil
  end

  def build_for_abi(abi, _toolchain, _release, _host_dep_dirs, target_dep_dirs, _options)
    install_dir = install_dir_for_abi(abi)

    src_dir = build_dir_for_abi(abi)
    @sqlite3_dir = target_dep_dirs['sqlite']

    system 'make',
           'native',
           'OS_NAME=Linux',
           "OS_ARCH=#{target(abi)}",
           "CC='#{src_dir}/cc'",
           "CCFLAGS='-I#{@sqlite3_dir}/include -L#{@sqlite3_dir}/libs/#{abi} -lsqlite3'",
           '-j', num_jobs

    bin_dir = File.join(install_dir, 'lib')
    FileUtils.mkdir_p bin_dir
    FileUtils.cp "target/sqlite-3.25.2-Linux-#{target(abi)}/libsqlitejdbc.so", bin_dir

    # this to make the build script happy, no actual includes
    include_dir = File.join(install_dir, 'include')
    FileUtils.mkdir_p include_dir
  end

  def gen_android_mk(pkg_dir, release)
    File.open("#{pkg_dir}/Android.mk", "w") do |f|
      f.puts ""
      f.puts "LOCAL_PATH := $(call my-dir)"
      f.puts ""
      f.puts "include $(CLEAR_VARS)"
      f.puts "LOCAL_MODULE := sqlitejdbc_shared"
      f.puts "LOCAL_SRC_FILES := libs/$(TARGET_ARCH_ABI)/libsqlitejdbc.so"
      f.puts "LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/include"
      f.puts "LOCAL_SHARED_LIBRARIES += libsqlite3_shared"
      f.puts "include $(PREBUILT_SHARED_LIBRARY)"
      f.puts ""
      f.puts "$(call import-module,../packages/#{import_module_path(@sqlite3_dir)})"
      f.puts ""
    end
  end

  # take two last components of the path
  def import_module_path(path)
    v = path.split('/')
    "#{v[v.size-2]}/#{v[v.size-1]}"
  end
end
