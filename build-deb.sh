#!/usr/bin/env bash
# 로컬 Remmina 작업 트리(미커밋 변경 포함)로 Ubuntu .deb 를 docker 컨테이너에서 빌드한다.
# 사용법: ./build-deb.sh [우분투버전]   (기본 24.04, 산출물: 소스 트리 밖 ../remmina-debbuild/<버전>)
# 컨테이너 안에서는 같은 스크립트가 --in-container / --test-in-container 로 다시 실행된다.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=packaging-common.sh
. "$SRC_DIR/packaging-common.sh"

UBUNTU_VERSION="${UBUNTU_VERSION:-24.04}"
DOCKER="${DOCKER:-docker}"
OUT_ROOT="${OUT_ROOT:-$(dirname "$SRC_DIR")/remmina-debbuild}"
DEB_MAINTAINER="${DEB_MAINTAINER:-Remmina hangulclip local build <root@localhost>}"

# 컨테이너 안 경로
C_SRC="/src"
C_OUT="/out"
C_BUILD="/build"

DEB_VERSION=""

set_deb_version() {
    DEB_VERSION="$VERSION+$FORK_TAG-1~ubuntu$UBUNTU_VERSION"
    echo "deb 버전: $DEB_VERSION"
}

# ---------- 호스트 ----------

# SELinux 가 켜져 있으면 볼륨 라벨 옵션(z: 여러 컨테이너가 공유)을 붙인다
volume_opt() {
    local mode="$1"
    if command -v selinuxenabled > /dev/null 2>&1 && selinuxenabled; then
        echo "$mode,z"
    else
        echo "$mode"
    fi
}

run_container() {
    local out_mode="$1"
    shift
    "$DOCKER" run --rm \
        -v "$SRC_DIR:$C_SRC:$(volume_opt ro)" \
        -v "$OUT_DIR:$C_OUT:$(volume_opt "$out_mode")" \
        -e UBUNTU_VERSION="$UBUNTU_VERSION" \
        -e GIT_REVISION="$GIT_REVISION" \
        -e FORK_TAG="$FORK_TAG" \
        -e DEB_MAINTAINER="$DEB_MAINTAINER" \
        -e HOST_UID="$(id -u)" \
        -e HOST_GID="$(id -g)" \
        "ubuntu:$UBUNTU_VERSION" bash "$C_SRC/build-deb.sh" "$@"
}

host_build() {
    OUT_DIR="$OUT_ROOT/$UBUNTU_VERSION"
    mkdir -p "$OUT_DIR"
    read_version
    read_git_revision
    set_deb_version
    echo "빌드 시작: $(date '+%F %T')"
    run_container rw --in-container
    echo "설치 테스트: $(date '+%F %T')"
    run_container ro --test-in-container
    print_result
}

print_result() {
    echo
    echo "생성된 deb ($OUT_DIR):"
    ls -1 "$OUT_DIR"/*"_${DEB_VERSION}_"*.deb
    echo
    echo "Ubuntu $UBUNTU_VERSION 설치 명령:"
    echo "  sudo apt install ./remmina_${DEB_VERSION}_amd64.deb ./remmina-common_${DEB_VERSION}_all.deb \\"
    echo "    ./remmina-plugin-rdp_${DEB_VERSION}_amd64.deb   (필요한 플러그인 deb 를 추가로 지정)"
}

# ---------- 컨테이너: 빌드 ----------

apt_setup() {
    export DEBIAN_FRONTEND=noninteractive
    sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends dpkg-dev patch ca-certificates > /dev/null
}

# 공식 소스 패키지에서 debian/ 을 받아 BUILD_SRC 에 붙인다
fetch_official_debian() {
    local official="$C_BUILD/official"
    mkdir -p "$official"
    (cd "$official" && apt-get source -qq --download-only remmina)
    tar -C "$BUILD_SRC" -xf "$official"/remmina_*.debian.tar.xz
    OFFICIAL_VERSION="$(dpkg-parsechangelog -l "$BUILD_SRC/debian/changelog" -S Version)"
    echo "공식 패키지 버전: $OFFICIAL_VERSION"
}

prepare_source() {
    mkdir -p "$C_BUILD"
    BUILD_SRC="$C_BUILD/remmina-$VERSION"
    make_tarball "$C_BUILD/remmina-$VERSION.tar.gz" "remmina-$VERSION"
    tar -C "$C_BUILD" -xzf "$C_BUILD/remmina-$VERSION.tar.gz"
}

# 작업 트리에 적용되지 않는 패치(이미 반영된 것 등)는 series 에서 뺀다
drop_stale_patches() {
    local series="$BUILD_SRC/debian/patches/series"
    local patch_name
    DROPPED_PATCHES=""
    [ -f "$series" ] || return 0
    for patch_name in $(grep -v '^#' "$series"); do
        if patch -d "$BUILD_SRC" -p1 --dry-run -f -s < "$BUILD_SRC/debian/patches/$patch_name" > /dev/null; then
            echo "패치 유지: $patch_name"
            continue
        fi
        echo "패치 제거(적용 불가/이미 반영): $patch_name"
        sed -i "/^$patch_name\$/d" "$series"
        rm -f "$BUILD_SRC/debian/patches/${patch_name:?}"
        DROPPED_PATCHES="$DROPPED_PATCHES $patch_name"
    done
}

add_git_revision_option() {
    sed -i "s|^\(\tdh_auto_configure -- \\\\\)$|\1\n\t\t-DREMMINA_GIT_REVISION=$GIT_REVISION \\\\|" \
        "$BUILD_SRC/debian/rules"
    grep -q "REMMINA_GIT_REVISION=$GIT_REVISION" "$BUILD_SRC/debian/rules" || {
        echo "debian/rules 에 REMMINA_GIT_REVISION 을 넣지 못했습니다" >&2
        exit 1
    }
}

add_changelog_entry() {
    local changelog="$BUILD_SRC/debian/changelog"
    local codename
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
    if ! dpkg --compare-versions "$DEB_VERSION" gt "$OFFICIAL_VERSION"; then
        echo "deb 버전($DEB_VERSION)이 공식($OFFICIAL_VERSION)보다 높지 않습니다" >&2
        exit 1
    fi
    {
        echo "remmina ($DEB_VERSION) $codename; urgency=medium"
        echo
        echo "  * Unofficial local build from working tree (git $GIT_REVISION)."
        echo "  * RDP: skip CF_TEXT targets when CF_UNICODETEXT is available."
        if [ -n "$DROPPED_PATCHES" ]; then
            echo "  * Drop patches not applicable to this tree:$DROPPED_PATCHES"
        fi
        echo
        echo " -- $DEB_MAINTAINER  $(date -R)"
        echo
        cat "$changelog"
    } > "$changelog.new"
    mv "$changelog.new" "$changelog"
}

build_packages() {
    apt-get build-dep -y -qq "$BUILD_SRC" > /dev/null
    (cd "$BUILD_SRC" && DEB_BUILD_OPTIONS="parallel=$(nproc)" dpkg-buildpackage -us -uc -b)
}

collect_output() {
    rm -f "${C_OUT:?}"/*.deb "${C_OUT:?}"/*.buildinfo "${C_OUT:?}"/*.changes
    cp "$C_BUILD"/*.deb "$C_BUILD"/*.buildinfo "$C_BUILD"/*.changes "$C_OUT/"
    chown "$HOST_UID:$HOST_GID" "$C_OUT"/*
}

container_build() {
    read_version
    read_git_revision
    set_deb_version
    apt_setup
    prepare_source
    fetch_official_debian
    drop_stale_patches
    add_git_revision_option
    add_changelog_entry
    build_packages
    collect_output
}

# ---------- 컨테이너: 설치 테스트 ----------

check_contains() {
    local file="$1"
    local text="$2"
    if grep -q -a -F "$text" "$file"; then
        echo "확인: $file 에 '$text' 있음"
    else
        echo "실패: $file 에 '$text' 없음" >&2
        exit 1
    fi
}

container_test() {
    local rdp_so arch
    read_version
    set_deb_version
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    arch="$(dpkg --print-architecture)"
    apt-get install -y -qq "$C_OUT/remmina_${DEB_VERSION}_$arch.deb" \
        "$C_OUT/remmina-common_${DEB_VERSION}_all.deb" \
        "$C_OUT/remmina-plugin-rdp_${DEB_VERSION}_$arch.deb" > /dev/null
    dpkg -l 'remmina*' | grep '^ii'
    echo "remmina --version: $(remmina --version 2>&1 || true)"
    check_contains /usr/bin/remmina "$GIT_REVISION"
    rdp_so="$(dpkg -L remmina-plugin-rdp | grep 'remmina-plugin-rdp.so$')"
    check_contains "$rdp_so" "skipped, CF_UNICODETEXT"
}

main() {
    case "${1:-}" in
        --in-container) container_build ;;
        --test-in-container) container_test ;;
        *)
            UBUNTU_VERSION="${1:-$UBUNTU_VERSION}"
            host_build
            ;;
    esac
}

main "$@"
