# Hyprland Templates

This repo contains `srcpkgs/` templates for Hyprland and related packages.

Use these templates inside a local clone of `void-packages`, then build with
`xbps-src`.

## Prebuilt packages

If you do not want to build locally, use:
`https://git.deadzone.lol/Wizzard/void-repo`

Follow that repo for binary repo setup and update instructions.

## Build from source

1. Clone `void-packages`:

```bash
git clone https://github.com/void-linux/void-packages.git
```

2. Copy this repo's templates into `void-packages/srcpkgs/`:

```bash
cp -r /path/to/hyprland-void/srcpkgs/* /path/to/void-packages/srcpkgs/
```

3. Update `common/shlibs` in `void-packages`.

```bash
cd /path/to/void-packages
nvim common/shlibs
```

Add these entries (or update existing ones to match):

```text
libaquamarine.so.9 aquamarine-0.10.0_2
libhyprcursor.so.0 hyprcursor-0.1.13_1
libhyprgraphics.so.4 hyprgraphics-0.5.0_1
libhyprlang.so.2 hyprlang-0.6.8_1
libhyprtoolkit.so.5 hyprtoolkit-0.5.3_1
libhyprutils.so.10 hyprutils-0.11.0_1
libhyprwire.so.3 hyprwire-0.3.0_3
libsdbus-c++.so.2 sdbus-cpp-2.2.1_1
libspng.so.0 libspng-0.7.4_1
libtomlplusplus.so.3 tomlplusplus-3.4.0_1
```

4. Bootstrap:

```bash
./xbps-src binary-bootstrap
```

5. Build the packages you want:

```bash
./xbps-src pkg hyprland
```

6. Install from local build output:

```bash
sudo xbps-install --repository hostdir/binpkgs/ hyprland hyprlock hyprpaper hyprpicker
```

## Build for x86_64-musl

```bash
cd /path/to/void-packages
./xbps-src -A x86_64-musl binary-bootstrap
./xbps-src -A x86_64-musl pkg hyprland
```
