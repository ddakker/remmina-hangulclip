# build-rpm.sh, build-deb.sh 공통 함수. 호출 전에 SRC_DIR 을 정해 두고 source 한다.

FORK_TAG="${FORK_TAG:-hangulclip}"
# tarball 에 넣지 않는 패키징 스크립트
PACKAGING_FILES="build-rpm.sh build-deb.sh packaging-common.sh"

VERSION=""
GIT_REVISION="${GIT_REVISION:-}"

read_version() {
    VERSION="$(sed -n 's/^[[:space:]]*VERSION[[:space:]]\+\([0-9.]\+\)[[:space:]]*$/\1/p' \
        "$SRC_DIR/CMakeLists.txt" | head -n 1)"
    if [ -z "$VERSION" ]; then
        echo "CMakeLists.txt 에서 VERSION 을 찾지 못했습니다" >&2
        exit 1
    fi
    echo "버전: $VERSION"
}

# 정보 창 "(git ...)" 에 표시: 업스트림 커밋 + 수정 표시. 이미 정해져 있으면 그대로 쓴다.
read_git_revision() {
    local commit
    if [ -z "$GIT_REVISION" ]; then
        commit="$(git -C "$SRC_DIR" rev-parse --short HEAD 2> /dev/null || echo "n/a")"
        GIT_REVISION="$commit-$FORK_TAG"
    fi
    echo "git 리비전: $GIT_REVISION"
}

# 작업 트리 기준 tarball(미커밋 변경 포함). 사용법: make_tarball <tarball 경로> <최상위 디렉토리 이름>
make_tarball() {
    local tarball="$1"
    local top_name="$2"
    local excludes=(--exclude=.git)
    local file
    for file in $PACKAGING_FILES; do
        excludes+=("--exclude=./$file")
    done
    rm -f "${tarball:?}"
    tar -C "$SRC_DIR" "${excludes[@]}" --transform "s|^\.|$top_name|" -czf "$tarball" .
    echo "tarball: $tarball"
}
