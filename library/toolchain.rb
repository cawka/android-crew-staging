require_relative 'global.rb'
require_relative 'arch.rb'


module Toolchain

  class LLVM_Official
    attr_reader :type, :name

    def initialize()
      @type = 'llvm'
      @name = "#{type}"
    end

    def c_compiler(arch, abi)
      "#{tc_prefix(abi)}/bin/#{target(arch)}-#{c_compiler_name}"
    end

    def cxx_compiler(arch, abi)
      "#{tc_prefix(abi)}/bin/#{target(arch)}-#{cxx_compiler_name}"
    end

    def tool(arch, name)
      case name
      when 'cpp'
        "#{c_compiler} -E"
      else
        "#{tc_prefix(arch)}/bin/#{tool_target(arch)}-#{name}"
      end
    end

    def c_compiler_name
      'clang'
    end

    def cxx_compiler_name
      'clang++'
    end

    def stl_lib_name
      'c++'
    end

    def stl_name
      "llvm"
    end

    # def search_path_for_stl_includes(abi)
    #   "-I#{Global::NDK_DIR}/sources/cxx-stl/llvm-libc++/include " \
    #   "-I#{Global::NDK_DIR}/sources/cxx-stl/llvm-libc++abi/include"
    # end

    # def search_path_for_stl_libs(abi)
    #   "-L#{Global::NDK_DIR}/platforms/android-23/arch-#{abi}/usr/lib "
    #   "-L#{Global::NDK_DIR}/sources/cxx-stl/llvm-libc++/libs/#{abi}"
    # end

    def cflags(abi)
      f = " -ffunction-sections -funwind-tables -fstack-protector-strong -Wno-invalid-command-line-argument -Wno-unused-command-line-argument -no-canonical-prefixes "
      case abi
      when /^armeabi-v7a/
        f += " -fpic  -march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16 -mthumb "
      when 'arm64-v8a'
        f += " -fpic "
      when 'x86'
        f += " -fPIC -mstackrealign "
      when 'x86_64'
        f += " -fPIC "
      end

      f += " -O0 -UNDEBUG -fno-limit-debug-info "
      f += " -g -fexceptions -frtti -DANDROID -D__ANDROID_API__=23 "
      f += " -Wa,--noexecstack -Wformat -Werror=format-security "
      f
    end

    def ldflags(abi)
      f = ''
      case abi
      when /^armeabi-v7a/
        f += " #{Global::NDK_DIR}/sources/cxx-stl/llvm-libc++/libs/armeabi-v7a/libunwind.a -Wl,--exclude-libs,libunwind.a -Wl,--fix-cortex-a8 "
      when 'arm64-v8a'
        f += "  "
      when 'x86'
        f += "  "
      when 'x86_64'
        f += "  "
      end
      f += " -no-canonical-prefixes -Wl,--build-id -nostdlib++ -Wl,--no-undefined -Wl,-z,noexecstack -Wl,-z,relro -Wl,-z,now -Wl,--warn-shared-textrel -Wl,--fatal-warnings "
      f += " -lgcc -Wl,--exclude-libs,libgcc.a -latomic -Wl,--exclude-libs,libatomic.a "
      f
    end

    def find_so_needs(lib, arch)
      readobj = "#{tc_prefix(arch)}/bin/llvm-readobj"
      Utils.run_command(readobj, '-needed-libs', lib).split("\n").select { |l| l =~ /.so/ }.map { |l| l.split(' ')[0].split('.')[0] }
    end

    def tc_prefix(_arch)
      "#{Global::NDK_DIR}/toolchains/llvm/prebuilt/#{Global::PLATFORM_NAME}"
    end

    def tool_target(arch)
      case arch.name
      when 'arm'
        'arm-linux-androideabi'
      when 'arm64'
        'aarch64-linux-android'
      when 'x86'
        'i686-linux-android'
      when 'x86_64'
        'x86_64-linux-android'
      else
        raise UnknownAbi.new(arch)
      end
    end
    
    def target(arch)
      case arch.name
      when 'arm'
        'armv7a-linux-androideabi23'
      when 'arm64'
        'aarch64-linux-android23'
      when 'x86'
        'i686-linux-android23'
      when 'x86_64'
        'x86_64-linux-android23'
      else
        raise UnknownAbi.new(arch)
      end
    end
  end

  
  LLVM_ndk = LLVM_Official.new()
  DEFAULT_LLVM = LLVM_ndk
  SUPPORTED_LLVM = [LLVM_ndk]

  # class Standalone
  #   attr_reader :base_dir, :sysroot_dir

  #   def initialize(arch, base_dir, gcc_toolchain, llvm_toolchain, with_packages, formula)
  #     @arch     = arch
  #     @base_dir = base_dir
  #     @gcc_toolchain = gcc_toolchain
  #     @llvm_toolchain = llvm_toolchain
  #     @bin_dir     = "#{base_dir}/bin"
  #     @sysroot_dir = "#{base_dir}/sysroot"

  #     args = ["#{Global::BASE_DIR}/crew",
  #             "-b",
  #             "make-standalone-toolchain",
  #             "--arch=#{arch.name}",
  #             "--install-dir=#{base_dir}",
  #             "--clean-install-dir",
  #             "--gcc-version=#{gcc_toolchain.version}"
  #            ]
  #     args << "--with-packages=#{with_packages.join(',')}" unless with_packages.empty?

  #     formula.system *args
  #   end

  #   def gcc
  #     tool '', 'gcc'
  #   end

  #   def gxx
  #     tool '', 'g++'
  #   end

  #   def tool(_arch, name)
  #     "#{tool_prefix}-#{name}"
  #   end

  #   def gcc_cflags(abi)
  #     @gcc_toolchain.cflags abi
  #   end

  #   def gcc_ldflags(abi)
  #     @gcc_toolchain.ldflags(abi).gsub("-L#{Global::NDK_DIR}/sources/crystax/libs/#{abi}", '')
  #   end

  #   def tool_prefix
  #     "#{@bin_dir}/#{@arch.host}"
  #   end

  #   def remove_dynamic_libcrystax
  #     FileUtils.rm "#{@base_dir}/#{@arch.host}/lib/libcrystax.so"
  #   end
  # end
end
