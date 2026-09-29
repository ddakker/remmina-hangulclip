#!/usr/bin/env bash
# 로컬 Remmina 작업 트리(미커밋 변경 포함)로 Fedora RPM 을 빌드한다.
# 사용법: ./build-rpm.sh   (산출물: 소스 트리 밖 ../remmina-rpmbuild/RPMS)
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=packaging-common.sh
. "$SRC_DIR/packaging-common.sh"

TOP_DIR="${TOP_DIR:-$(dirname "$SRC_DIR")/remmina-rpmbuild}"
RELEASE_TAG="${RELEASE_TAG:-100.$FORK_TAG}"
SRPM_NAME="remmina"

SPEC=""

# 공식 SRPM 에서 spec 과 Source1 을 받아온다(최초 1회)
fetch_official_srpm() {
    local srpm_dir="$TOP_DIR/official"
    if [ -f "$srpm_dir/remmina.spec" ]; then
        return
    fi
    mkdir -p "$srpm_dir"
    (cd "$srpm_dir" && dnf download --source "$SRPM_NAME")
    (cd "$srpm_dir" && rpm2cpio ./*.src.rpm | cpio -idm --quiet)
}

prepare_spec() {
    fetch_official_srpm
    mkdir -p "$TOP_DIR"/{SPECS,SOURCES,BUILD,RPMS,SRPMS}
    cp "$TOP_DIR/official/pluginBuild-CMakeLists.txt" "$TOP_DIR/SOURCES/"

    SPEC="$TOP_DIR/SPECS/remmina.spec"
    local today
    today="$(LC_ALL=C date '+%a %b %d %Y')"
    sed -e "s/^Version:.*/Version: $VERSION/" \
        -e "s/^Release:.*/Release: $RELEASE_TAG%{?dist}/" \
        -e 's|^Source0:.*|Source0: %{name}-%{version}.tar.gz|' \
        -e 's|^%autosetup .*|%autosetup -p1 -n %{name}-%{version}|' \
        -e '/^%global commit /d' \
        -e "s|^%cmake \\\\$|%cmake -DREMMINA_GIT_REVISION=$GIT_REVISION \\\\|" \
        -e "/^%changelog/a * $today local build - $VERSION-$RELEASE_TAG\\n- Build from local source tree\\n" \
        "$TOP_DIR/official/remmina.spec" > "$SPEC"
    echo "spec: $SPEC"
}

make_rpm_tarball() {
    make_tarball "$TOP_DIR/SOURCES/remmina-$VERSION.tar.gz" "remmina-$VERSION"
}

missing_build_deps() {
    local dep
    rpmspec -q --buildrequires "$SPEC" | while read -r dep; do
        rpm -q --whatprovides "${dep%% *}" > /dev/null 2>&1 || echo "$dep"
    done
}

install_deps() {
    local missing
    missing="$(missing_build_deps)"
    if [ -z "$missing" ]; then
        echo "빌드 의존성 모두 설치됨"
        return
    fi
    echo "누락된 빌드 의존성:"
    echo "$missing"
    if ! sudo -n true 2> /dev/null; then
        echo "sudo 비밀번호가 필요합니다. 아래 명령을 직접 실행한 뒤 다시 실행하세요:" >&2
        echo "  sudo dnf builddep -y $SPEC" >&2
        exit 1
    fi
    sudo dnf builddep -y "$SPEC"
}

build() {
    echo "빌드 시작: $(date '+%F %T')"
    rpmbuild -bb --define "_topdir $TOP_DIR" "$SPEC"
}

print_result() {
    local rpms
    rpms="$(find "$TOP_DIR/RPMS" -name "*-$VERSION-$RELEASE_TAG*.rpm" ! -name '*debug*' | sort)"
    echo
    echo "생성된 RPM:"
    echo "$rpms"
    echo
    echo "설치 명령:"
    echo "  cd $TOP_DIR/RPMS/$(uname -m) && sudo dnf install \\"
    echo "    ./remmina-$VERSION-*.rpm ./remmina-plugins-rdp-$VERSION-*.rpm"
    echo "  (필요한 플러그인 RPM 을 추가로 지정)"
}

main() {
    read_version
    read_git_revision
    prepare_spec
    make_rpm_tarball
    install_deps
    build
    print_result
}

main "$@"
