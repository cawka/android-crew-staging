class Libjpeg < Package

  desc "JPEG image manipulation library"
  homepage "http://www.ijg.org"
  url "http://www.ijg.org/files/jpegsrc.v${version}.tar.gz"

  release version: '9b', crystax_version: 1, sha256: '17a82eb7f373038b40076ebb8d7aaa94c5381a9021cce7b61a498cf87a759697'

  build_copy 'README'

  def build_for_abi(abi, _toolchain, _release, _host_dep_dirs, _target_dep_dirs)
    install_dir = install_dir_for_abi(abi)
    args =  [ "--prefix=#{install_dir}",
              "--host=#{host_for_abi(abi)}",
              "--enable-shared",
              "--enable-static",
              "--with-pic",
              "--disable-ld-version-script"
            ]

    system './configure', *args
    system 'make', '-j', num_jobs, 'V=1'
    system 'make', 'install'

    # remove unneeded files
    FileUtils.rm Dir["#{install_dir}/lib/*.la"]
  end
end