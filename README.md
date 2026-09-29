> [!WARNING]
> **비공식 수정 버전입니다 / This is an unofficial modified version.**
> Remmina 프로젝트와 관계없으며 공식 지원을 받지 않습니다.
> It is not affiliated with or supported by the Remmina project.
> 원본 / Upstream: https://gitlab.com/Remmina/Remmina

## 수정 이유 / Why

**한국어**
Windows RDP 세션에서 한글을 복사해 VS Code, Chrome(Wayland) 등에 붙여넣으면 `\Uffffffff` 로 깨집니다.
GTK 가 `TEXT`/`text/plain` 클립보드 형식을 Latin-1 로 변환하기 때문입니다.
같은 문제를 다루는 업스트림 MR([!2773](https://gitlab.com/Remmina/Remmina/-/merge_requests/2773))이
아직 병합되지 않아 직접 수정했습니다.

**English**
Korean text copied from a Windows RDP session is pasted as `\Uffffffff` in apps such as VS Code and
Chrome on Wayland, because GTK converts the `TEXT`/`text/plain` targets to Latin-1.
The upstream MR for this issue ([!2773](https://gitlab.com/Remmina/Remmina/-/merge_requests/2773))
is not merged yet, so this fork carries its own fix.

## 수정 내역 / Changes

- `plugins/rdp/rdp_cliprdr.c`
  - 서버가 CF_UNICODETEXT 를 주면 CF_TEXT(`TEXT`, `text/plain`)를 광고하지 않음
  - Skip CF_TEXT targets when CF_UNICODETEXT is available
- `build-rpm.sh`: Fedora 공식 spec 기반 로컬 RPM 빌드 / Local RPM build based on the Fedora spec
- `build-deb.sh`: Ubuntu 공식 debian/ 기반 docker 컨테이너 deb 빌드 / Ubuntu .deb build in docker, based on the official debian/
- `docs-plan/`: 원인 분석 문서와 패치 파일 / Root cause notes and patch file

### Ubuntu 빌드·설치 / Build and install on Ubuntu

```sh
./build-deb.sh 24.04        # 또는 26.04 / or 26.04 (docker 필요 / requires docker)
cd ../remmina-debbuild/24.04
sudo apt install ./remmina_*.deb ./remmina-common_*.deb ./remmina-plugin-rdp_*.deb
```

빌드된 버전은 정보 창에 `1.4.43 (git <커밋>-hangulclip)` 으로 표시됩니다.
Builds show `1.4.43 (git <commit>-hangulclip)` in the About dialog.

라이선스는 원본과 같은 GPLv2+ 입니다. / Licensed under GPLv2+, same as upstream.

---

[![](https://img.shields.io/liberapay/receives/Remmina.svg?logo=liberapay)](https://liberapay.com/Remmina/donate)
[![](https://img.shields.io/liberapay/patrons/remmina.svg?logo=liberapay)](https://liberapay.com/Remmina/donate)
[![](https://opencollective.com/remmina/tiers/badge.svg)](https://opencollective.com/remmina)
[![Build Status](https://gitlab.com/Remmina/Remmina/badges/master/pipeline.svg)](https://gitlab.com/Remmina/Remmina/pipelines)
[![Translation status](https://hosted.weblate.org/widgets/remmina/-/remmina/svg-badge.svg)](https://hosted.weblate.org/engage/remmina/?utm_source=widget)
[![remmina](https://snapcraft.io//remmina/badge.svg)](https://snapcraft.io/remmina)

## Remmina remote desktop client

*Use other desktops remotely, from a tiny screen or large monitors.*


* RDP, VNC, SPICE, X2Go, SSH, WWW (HTTP protocol) and EXEC network protocols are supported.
* Written in GTK, with a port to Qt underway.
* Released as "remmina" (the main program) and "remmina-plugins".

### Installation

[How to install Remmina](https://remmina.org/how-to-install-remmina/),
editable on [the wiki](https://gitlab.com/Remmina/Remmina/-/wikis/home).

### Configuration

Set up everything from the graphical interface, or from $HOME/.config/remmina

### Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new merge request

There are [other ways](CONTRIBUTING.md) to contribute too, get in contact on IRC (#remmina on libera.chat), or on [Matrix](https://riot.im/app/#/group/+remmina:matrix.org).

### Donations

This is the website [donation page](https://remmina.org/wp/donations/).
[THANKS](THANKS.md) is a list of supporters.

### Authors

Maintained by [Hiroyuki Tanaka](https://gitlab.com/myheroyuki), [Antenore Gatta](https://gitlab.com/antenore), [Giovanni Panozzo](https://gitlab.com/giox069) and [Allan Nordhøy](https://gitlab.com/kingu).
Add yourself in [AUTHORS](AUTHORS) if you have contributed.

### Resources

 * [Website](https://www.remmina.org/)
 * IRC room on libera.chat, in the #remmina channel, you can also use a [web client](https://web.libera.chat/?nick=remminer|?#remmina).

### License

Copylefted libre software, licensed [GPLv2+](https://gitlab.com/Remmina/Remmina/blob/master/COPYING). \
Initially developed by [Vic Lee](https://github.com/llyzs).
