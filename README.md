# b2i2b

Copy a block device to a compressed image, and back.

```
b2i /dev/sda backup.zst      # block device -> image
i2b backup.zst /dev/sda      # image -> block device
```

One bash script, two symlinks. Under the hood it is just
`dd | pv | zstd` with sane defaults; nothing is reinvented.

## Usage

```
b2i [-f] <block-device> <image>
i2b [-f] <image> <block-device>
b2i2b {b2i|i2b} [-f] <src> <dst>     # without the symlinks
```

`-f` / `--force` lets `b2i` overwrite an existing image, and lets `i2b`
write to a device that is mounted, swapped on, or held by LVM/md/dm-crypt.

## Checks

- `b2i` requires the first argument to be a block device and the second a
  file that does not exist yet. It warns if the device is in use, since the
  image may then be inconsistent. A failed or interrupted run removes the
  partial image.
- `i2b` requires the first argument to be a regular file and the second a
  block device. It refuses to write to a device that is in use, and refuses
  a raw image that is larger than the device.
- Both catch swapped arguments ("did you mean i2b?").

## Compression

Chosen by the image's file extension:

| extension      | tool                                        |
|----------------|---------------------------------------------|
| `.gz` `.gzip`  | gzip, or pigz when installed                |
| `.bz2`         | bzip2, or pbzip2/lbzip2 when installed      |
| `.xz`          | xz `-T0`                                    |
| `.zst` `.zstd` | zstd `-T0`                                  |
| `.lz4`         | lz4                                         |
| `.lzo`         | lzop                                        |
| `.lz`          | lzip                                        |
| anything else  | none, raw image (`.img`, `.raw`, ...)       |

Compression levels are the tools' defaults. Tune them through the tools'
own environment variables, e.g. `XZ_OPT=-9`, `GZIP=-1`, `ZSTD_CLEVEL=19`.

## Progress

Uses `pv` when installed (bar, throughput, ETA). Without `pv` it falls
back to `dd status=progress`, which shows bytes and rate but no ETA.

`B2I2B_BS` overrides the dd block size (default `4M`).

## Install

```
sudo make install            # to /usr/local/bin
sudo make PREFIX=/usr install
```

Dependencies: bash, coreutils (dd, numfmt), plus `pv` and whichever
compressors you use. `blockdev` or `lsblk` are used for the device size
when present, with a `/sys` fallback.

## Testing

`tests/loop-test.sh` runs both directions end to end on loop devices,
including the refusal and warning paths. It needs root, `losetup`,
`mkfs.ext4` and `zstd`:

```
sudo make test
```

## Nix / home-manager

The repo is a flake. In your home-manager flake:

```nix
inputs.b2i2b = {
  url = "github:rck/b2i2b";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

```nix
home.packages = [ inputs.b2i2b.packages.${pkgs.system}.default ];
```

The package wraps the script so pv and all compressors are on its PATH,
independent of what else is installed.

## License

GPL-3.0-or-later, see `LICENSE`.
