# Building the syncthing Keel package

The build runs on the Keel build host. It needs Go 1.26.2, installed
there as a pinned tool, because Debian trixie ships golang 1.24 and
go.mod needs go 1.26.2.

## The pinned Go

Install upstream Go as `/usr/local/go1.26`. There is no
`/usr/local/go` on purpose: every build names its toolchain
explicitly, so a default `go` on PATH cannot drift between
toolchains.

```
curl -fLO https://go.dev/dl/go1.26.2.linux-amd64.tar.gz
# verify the sha256 against https://go.dev/dl/?mode=json (the entry of
# go1.26.2, file go1.26.2.linux-amd64.tar.gz) before unpacking
echo "<sha256 from go.dev>  go1.26.2.linux-amd64.tar.gz" | sha256sum -c -
rm -rf /usr/local/go1.26
tar -C /usr/local -xzf go1.26.2.linux-amd64.tar.gz
mv /usr/local/go /usr/local/go1.26
/usr/local/go1.26/bin/go version
```

Installed now: go1.26.2. The sha256 this install was verified against
is recorded in the commit that installed it; `sha256sum
go1.26.2.linux-amd64.tar.gz` must match the value
`https://go.dev/dl/?mode=json` lists for go1.26.2 before unpacking.

The tarball the source came from: the release
`https://github.com/syncthing/syncthing/releases/tag/v2.1.6`, file
`syncthing-source-v2.1.6.tar.gz`, sha256
`4927b6b0f3a5c395486bad6accf128aa7c30bfd41b43ad0e423c4f85dd6677f2`
(the digest the release publishes). It carries `vendor/`, so the build
never touches the network.

## Build

```
git clone git@git.pop.coop:Keel-Linux/syncthing.git
cd syncthing
debuild -us -uc
```

debian/rules puts `/usr/local/go1.26/bin` at the front of PATH, so the
pinned toolchain is the one the build uses. The package is native
(format 3.0 (native)): the repository carries the upstream source, so
no orig tarball is needed.

## Test

```
tests/run.sh            # static checks, then the .deb checks
```

The .deb checks need the .deb one directory up, as debuild leaves it:
`../syncthing_2.1.6+keel1_amd64.deb`.

## Publish

The publish flow of the apt repository
(`git@git.pop.coop:Keel-Linux/apt.git`, docs/layout.md): copy the
`.deb`, `.changes` and `.buildinfo` to `/srv/keel-apt/incoming` on the
build host, then `bin/publish` there. It lands in trixie-testing,
signed. Promotion to trixie is the maintainer's own act with
`bin/promote`.
