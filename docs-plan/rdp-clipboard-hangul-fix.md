# RDP 클립보드 한글 깨짐 수정

## 증상
Windows RDP 세션에서 한글 복사 → VS Code/Chrome(Wayland) 붙여넣기 시 `\Uffffffff` 로 깨짐.
Konsole 등 `UTF8_STRING` 을 요청하는 앱은 정상.

## 원인 (`plugins/rdp/rdp_cliprdr.c`)
- 서버가 CF_TEXT 를 주면 `text/plain`, `TEXT` 타깃을 광고한다.
- 붙여넣기 시 `gtk_selection_data_set_text()` 는 `TEXT`/`text/plain` 요청을 Latin-1 로 변환한다.
  비 ASCII 문자는 `\uXXXX` 로 바뀌고, CF_TEXT 의 CP949 바이트는 잘못된 UTF-8 이라 `\Uffffffff` 가 된다.

## 수정
서버 포맷 목록에 CF_UNICODETEXT 가 있으면 CF_TEXT 는 광고하지 않는다.
로컬 앱은 `text/plain;charset=utf-8`, `UTF8_STRING` 만 보게 되어 UTF-8 로 받는다.
Windows 는 CF_TEXT 를 복사하면 CF_UNICODETEXT 를 자동 합성하므로 텍스트 복사가 빠지지 않는다.
CF_UNICODETEXT 가 없는 서버는 기존 동작을 유지한다.

패치: `rdp-clipboard-hangul.patch`

## 참고
- 업스트림 MR !2773 (같은 증상, TEXT/text/plain 광고 제거 방식, 미병합)
  https://gitlab.com/Remmina/Remmina/-/merge_requests/2773

## 빌드
`./build-rpm.sh` → Fedora RPM 생성 후 `sudo dnf install` 로 설치.
정보 창 버전은 `1.4.43 (git <업스트림커밋>-hangulclip)` 으로 표시된다(`-DREMMINA_GIT_REVISION`).
같은 Release 로 다시 빌드했으면 `sudo dnf reinstall` 로 설치한다.

### Ubuntu deb (`build-deb.sh`)
`./build-deb.sh [24.04|26.04]` (기본 24.04, `UBUNTU_VERSION` 환경변수도 가능).
docker 컨테이너(`ubuntu:<버전>`)에서 빌드하므로 호스트에는 docker 만 있으면 된다.
산출물: `../remmina-debbuild/<버전>/*.deb` (소유자는 실행한 사용자).

동작 순서:
1. 소스 트리를 읽기 전용(`/src`)으로 마운트, 컨테이너 안에서 작업 트리 tarball(미커밋 변경 포함, `.git`·빌드 스크립트 제외)을 풀어 사용
2. deb-src 를 켜고 `apt-get source remmina` 로 공식 `debian/` 을 가져옴
3. 작업 트리에 안 맞는 `debian/patches` 는 제거(dry-run 실패 = 이미 반영됨).
   1.4.43 기준 `lp2161512.patch` 는 master 에 이미 들어 있어 제거, `do-not-phone-home.patch` 는 유지
4. `debian/rules` 의 `dh_auto_configure --` 에 `-DREMMINA_GIT_REVISION=<커밋>-hangulclip` 추가
5. `debian/changelog` 에 `1.4.43+hangulclip-1~ubuntu<버전>` 항목 추가
6. `apt-get build-dep` → `dpkg-buildpackage -us -uc -b`
7. 새 컨테이너에서 `apt install` 설치 테스트, 바이너리에 리비전·rdp 플러그인에 `skipped, CF_UNICODETEXT` 문자열 확인

버전은 공식(`1.4.43+dfsg-0ubuntu0.<버전>.N`)보다 높아야 apt 가 공식 패키지로 되돌리지 않는다.
`1.4.43-...` 는 `1.4.43+dfsg` 보다 낮으므로 `1.4.43+hangulclip` 을 쓴다(`+h` > `+d`). 스크립트가 빌드 전에 비교해 확인한다.

설치(Ubuntu):
```sh
sudo apt install ./remmina_*.deb ./remmina-common_*.deb ./remmina-plugin-rdp_*.deb
```
SELinux 가 켜진 호스트에서는 볼륨에 `z` 옵션을 자동으로 붙인다(꺼져 있으면 생략).

공통 로직(버전 읽기, git 리비전, 작업 트리 tarball)은 `packaging-common.sh` 에 있고 두 스크립트가 source 한다.
