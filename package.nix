{ lib
, stdenvNoCC
, bash
, coreutils
, util-linux
, pv
, gzip
, pigz
, bzip2
, xz
, zstd
, lz4
, lzop
, lzip
}:

stdenvNoCC.mkDerivation {
  pname = "b2i2b";
  version = "0.1.0";

  src = ./.;

  buildInputs = [ bash ];

  dontBuild = true;

  # The script dispatches on $(basename "$0"), so b2i/i2b must stay plain
  # symlinks to the real script. wrapProgram would rename it to
  # .b2i2b-wrapped (exec -a does not change $0 of a #! script), which
  # breaks that dispatch. Patch PATH into the script instead.
  postPatch = ''
    substituteInPlace b2i2b --replace-fail 'set -euo pipefail' \
      'set -euo pipefail
export PATH="${lib.makeBinPath [
  coreutils util-linux pv gzip pigz bzip2 xz zstd lz4 lzop lzip
]}:$PATH"'
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 b2i2b $out/bin/b2i2b
    ln -s b2i2b $out/bin/b2i
    ln -s b2i2b $out/bin/i2b
    runHook postInstall
  '';

  meta = with lib; {
    description = "Copy block devices to compressed images and back";
    homepage = "https://github.com/rck/b2i2b";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "b2i2b";
  };
}
