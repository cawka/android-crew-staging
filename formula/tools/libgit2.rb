class Libgit2 < BuildDependency

  desc "A portable, pure C implementation of the Git core methods provided as a re-entrant linkable library with a solid API"
  homepage 'https://libgit2.github.com/'
  url 'https://github.com/libgit2/libgit2/archive/v${version}.tar.gz'

  release version: '0.24.1', crystax_version: 1, sha256: { linux_x86_64:   '0',
                                                           darwin_x86_64:  '0',
                                                           windows_x86_64: '0',
                                                           windows:        '0'
                                                         }

  depends_on 'zlib'
  depends_on 'openssl'
  depends_on 'libssh2'

  def build_for_platform(platform, release, options, dep_dirs)
    install_dir = install_dir_for_platform(platform, release)
    zlib_dir    = dep_dirs[platform.name]['zlib']
    openssl_dir = dep_dirs[platform.name]['openssl']
    libssh2_dir = dep_dirs[platform.name]['libssh2']

    FileUtils.cp_r File.join(src_dir, '.'), '.'

    build_env['EXTRA_CFLAGS']   = "#{platform.cflags}"
    build_env['EXTRA_DEFINES']  = "-DGIT_SSL -DOPENSSL_SHA1 -DGIT_SSH"
    build_env['EXTRA_INCLUDES'] = "-I#{zlib_dir}/include -I#{openssl_dir}/include -I#{libssh2_dir}/include"

    make_args = ['-f', 'Makefile.crystax']

    if platform.target_os == 'windows'
      build_env['EXTRA_DEFINES'] += " -DGIT_WIN32"
      make_args << 'MINGW=1'
    end

    system 'make', *make_args

    FileUtils.mkdir_p ["#{install_dir}/lib", "#{install_dir}/include"]
    #
    FileUtils.cp   './libgit2.a',      "#{install_dir}/lib/"
    FileUtils.cp   './include/git2.h', "#{install_dir}/include/"
    FileUtils.cp_r './include/git2',   "#{install_dir}/include/"
  end
end