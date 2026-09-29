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
