{ lib
, stdenvNoCC
, makeWrapper
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

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 b2i2b $out/bin/b2i2b
    ln -s b2i2b $out/bin/b2i
    ln -s b2i2b $out/bin/i2b
    runHook postInstall
  '';

  # makeWrapper's wrapper does `exec -a "$0"`, so the script still sees
  # b2i / i2b as its name when called through the symlinks.
  postFixup = ''
    wrapProgram $out/bin/b2i2b --prefix PATH : ${lib.makeBinPath [
      coreutils util-linux pv gzip pigz bzip2 xz zstd lz4 lzop lzip
    ]}
  '';

  meta = with lib; {
    description = "Copy block devices to compressed images and back";
    homepage = "https://github.com/rck/b2i2b";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "b2i2b";
  };
}
