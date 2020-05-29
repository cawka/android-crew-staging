class Sqlite < Package

  desc "SQLite library"
  homepage "https://sqlite.org/"
  url "https://sqlite.org/2020/sqlite-amalgamation-${block}.zip" do |r| ('%s%02d%02d00' % r.version.split('.')).gsub(' ', '0') end

  release version: '3.32.1', crystax_version: 1

  build_options setup_env: false
  build_libs 'libsqlite3'

  def build_for_abi(abi, _toolchain, _release, _host_dep_dirs, _target_dep_dirs, _options)
    cwd = Dir.pwd
    ['static', 'shared'].each do |libtype|
      FileUtils.mkdir_p "#{cwd}/#{libtype}/jni"
      File.open("#{cwd}/#{libtype}/jni/Android.mk", "w") do |f|
        f.puts 'LOCAL_PATH := $(call my-dir)'
        f.puts 'include $(CLEAR_VARS)'
        f.puts 'LOCAL_MODULE := sqlite3'
        f.puts "LOCAL_SRC_FILES := #{cwd}/sqlite3.c"
        f.puts "LOCAL_INCLUDES := #{cwd}/"
        f.puts 'LOCAL_CFLAGS := -Wall -Wno-unused -Wno-multichar -Wno-strict-aliasing -Werror'
        f.puts 'LOCAL_CFLAGS += -fno-exceptions -fmessage-length=0'
        f.puts 'LOCAL_CFLAGS += -DSQLITE_THREADSAFE=1'
        f.puts "include $(BUILD_#{libtype.upcase}_LIBRARY)"
      end

      # Without this, NDK 21 somehow was adding libstdc++.so dependency, even though all code is just C
      File.open("#{cwd}/#{libtype}/jni/Application.mk", "w") do |f|
        f.puts 'APP_STL := c++_shared'
        f.puts 'APP_CPPFLAGS += -fexceptions -frtti -std=c++14'
        f.puts 'APP_PLATFORM := android-23'
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
