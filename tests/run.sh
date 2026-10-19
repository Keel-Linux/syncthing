#!/bin/sh
# Tests of the syncthing Keel packaging. Plain shell, no bats needed.
#
#   tests/run.sh --static   packaging metadata checks only
#   tests/run.sh --built    checks the built .deb (path as argument 2,
#                           default: the .deb one directory up)
#   tests/run.sh            both: static checks, then the .deb checks when
#                           a .deb is found one directory up
#
set -eu

cd "$(dirname "$0")/.."

pass=0
fail=0

ok() {
    pass=$((pass + 1))
    printf 'ok %d - %s\n' "$pass" "$1"
}

bad() {
    fail=$((fail + 1))
    printf 'not ok - %s\n' "$1" >&2
}

check() {
    # check NAME COMMAND...: ok when the command exits 0
    name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        ok "$name"
    else
        bad "$name"
    fi
}

# --- static packaging checks -------------------------------------------------

static_checks() {
    check "debian/control declares debhelper-compat 13" \
        grep -q "debhelper-compat (= 13)" debian/control

    check "debian/control has no golang build dependency" \
        sh -c '! grep -qiE "^ golang|^ golang-|golang-any|golang-go" debian/control'

    check "debian/control has no dh-golang" \
        sh -c '! grep -q "dh-golang" debian/control'

    check "debian/control has no node or npm build dependency" \
        sh -c '! grep -qiE "node|npm" debian/control'

    check "debian/rules builds with -mod=vendor" \
        grep -q -- "-mod=vendor" debian/rules

    check "debian/rules never fetches modules (GOPROXY off)" \
        grep -q "GOPROXY.*off" debian/rules

    check "debian/rules pins the toolchain (GOTOOLCHAIN local)" \
        grep -q "GOTOOLCHAIN.*local" debian/rules

    check "debian/rules uses the pinned Go of the build host" \
        grep -q "/usr/local/go1.26/bin" debian/rules

    check "debian/rules has no dh-golang" \
        sh -c '! grep -q "dh-golang" debian/rules'

    check "vendor/modules.txt is present" \
        test -s vendor/modules.txt

    check "no systemd unit is installed" \
        sh -c '! ls debian/ | grep -qE "\.service$" && \
            ! grep -q "dh_installsystemd" debian/rules && \
            ! grep -q "sysusers" debian/control'

    check "no maintainer script beyond the standard" \
        sh -c 'ls debian/ | grep -qE "^(pre|post)(inst|rm)" && exit 1 || exit 0'
}

# --- checks of the built .deb ------------------------------------------------

built_checks() {
    deb="$1"
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT

    check "the .deb exists" test -f "$deb"

    check "the package field is syncthing" \
        sh -c "dpkg-deb --info '$deb' | grep -q '^ Package: syncthing$'"

    check "the version is 2.1.6+keel1" \
        sh -c "dpkg-deb --info '$deb' | grep -q '^ Version: 2.1.6+keel1$'"

    check "the section is net" \
        sh -c "dpkg-deb --info '$deb' | grep -q '^ Section: net$'"

    check "the .deb installs usr/bin/syncthing" \
        sh -c "dpkg-deb --contents '$deb' | grep -q 'usr/bin/syncthing'"

    check "the .deb installs no systemd unit" \
        sh -c "! dpkg-deb --contents '$deb' | grep -qE 'systemd|\.service'"

    check "the .deb installs the overlay notice" \
        sh -c "dpkg-deb --contents '$deb' | grep -q 'usr/share/doc/syncthing/NOTICE'"

    dpkg-deb --extract "$deb" "$work/root"

    check "the binary runs and reports v2.1.6" \
        sh -c "'$work/root/usr/bin/syncthing' --version | grep -q 'v2.1.6'"

    check "the binary generates a config in a fresh home" \
        sh -c "'$work/root/usr/bin/syncthing' generate -H '$work/home' \
            >/dev/null 2>&1 && test -f '$work/home/config.xml'"

    check "the binary listens on a test port for 3 seconds" \
        sh -c "'$work/root/usr/bin/syncthing' serve -H '$work/home' --no-browser \
            --gui-address 127.0.0.1:18384 >'$work/log' 2>&1 &
        pid=\$!
        sleep 3
        alive=0
        kill -0 \$pid 2>/dev/null && alive=1
        listening=0
        ss -ltn 2>/dev/null | grep -q 127.0.0.1:18384 && listening=1
        kill \$pid 2>/dev/null || true
        wait \$pid 2>/dev/null || true
        test \$alive = 1 -a \$listening = 1"
}

# --- main --------------------------------------------------------------------

mode="${1:-all}"
case "$mode" in
    --static)
        static_checks
        ;;
    --built)
        deb="${2:-../syncthing_2.1.6+keel1_amd64.deb}"
        built_checks "$deb"
        ;;
    *)
        static_checks
        deb="../syncthing_2.1.6+keel1_amd64.deb"
        if [ -f "$deb" ]; then
            built_checks "$deb"
        else
            printf 'no .deb at %s: only the static checks ran\n' "$deb"
        fi
        ;;
esac

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
