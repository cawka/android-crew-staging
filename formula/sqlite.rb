class Sqlite < Library

  desc "SQLite library"
  homepage "https://sqlite.org/"
  url "https://sqlite.org/2015/sqlite-amalgamation-${block}.zip" do |v| ('%-2s%-2s%-3s' % v.split('.')).gsub(' ', '0') end

  release version: '3.9.2', crystax_version: 1, sha256: '90e89c0554bbdbb74941ff93672583c3a1ed6255d3696cabab5751130ea5a0dc'

  build_options setup_env: false
  build_libs 'libsqlite3'

  def build_for_abi(abi, _toolchain, _release, _dep_dirs)
    cwd = Dir.pwd
    ['static', 'shared'].each do |libtype|
      FileUtils.mkdir_p "#{cwd}/#{libtype}/jni"
      File.open("#{cwd}/#{libtype}/jni/Android.mk", "w") do |f|
        f.puts 'LOCAL_PATH := $(call my-dir)'
        f.puts 'include $(CLEAR_VARS)'
        f.puts 'LOCAL_MODULE := sqlite3'
        f.puts "LOCAL_SRC_FILES := #{cwd}/sqlite3.c"
        f.puts "LOCAL_INCLUDES := #{cwd}/"
        f.puts 'LOCAL_CFLAGS := -Wall -Wno-unused -Wno-multichar -Wstrict-aliasing=2 -Werror'
        f.puts 'LOCAL_CFLAGS += -Wno-strict-aliasing' if ['x86', 'x86_64', 'arm64-v8a'].include? abi
        f.puts 'LOCAL_CFLAGS += -fno-exceptions -fmessage-length=0'
        f.puts 'LOCAL_CFLAGS += -DSQLITE_THREADSAFE=1'
        f.puts "include $(BUILD_#{libtype.upcase}_LIBRARY)"
      end

      system "#{Global::NDK_DIR}/ndk-build", "-C", "#{cwd}/#{libtype}", "APP_ABI=#{abi}", "V=1"

      install_dir = install_dir_for_abi(abi)
      FileUtils.mkdir_p ["#{install_dir}/lib", "#{install_dir}/include"]
      ext = libtype == 'static' ? 'a' : 'so'
      FileUtils.cp "#{cwd}/#{libtype}/obj/local/#{abi}/libsqlite3.#{ext}", "#{install_dir}/lib/"
      FileUtils.cp Dir["#{cwd}/*.h"], "#{install_dir}/include/"
    end
  end
end