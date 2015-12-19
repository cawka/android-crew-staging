class LibjpegTurbo < Library

  desc "JPEG image codec that aids compression and decompression"
  homepage "http://www.libjpeg-turbo.org/"
  url "https://downloads.sourceforge.net/project/libjpeg-turbo/${version}/libjpeg-turbo-${version}.tar.gz"

  release version: '1.4.2', crystax_version: 1, sha256: '0'

  build_libs 'libturbojpeg', 'libjpeg'
  build_options sysroot_in_cflags: false

  def build_for_abi(abi, _)
    args =  [ "--prefix=#{install_dir_for_abi(abi)}",
              "--host=#{host_for_abi(abi)}",
              "--enable-shared",
              "--enable-static",
              "--with-pic",
              "--disable-ld-version-script"
            ]
    args << '--without-simd' if abi == 'mips'

    system './configure', *args
    system 'make', '-j', num_jobs
    system 'make', 'install'
  end
end
