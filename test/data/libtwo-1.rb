class Libtwo < Formula
  include Library

  desc "Library Two"
  homepage "http://www.libtwo.org"

  release version: '1.1.0', crystax_version: 1, sha256: '3eb37fa09183a978b97fb81ad70387d852888804e1f15da9bdfc9e895bd2e137'

  depends_on 'libone'
end
