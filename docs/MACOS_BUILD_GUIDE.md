# OneDesk macOS 로컬 빌드 가이드

## 요구 사항

- macOS (Apple Silicon / aarch64)
- Xcode Command Line Tools
- Homebrew

## 1. Rust 설치 (v1.81)

macOS 빌드는 Rust 1.81이 필요합니다 (`cidre` 크레이트 요구사항).

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.81.0
source "$HOME/.cargo/env"
rustup component add rustfmt
```

## 2. 빌드 도구 설치

```bash
brew install llvm create-dmg pkg-config cmake nasm cocoapods
brew install --cask flutter
```

설치되는 도구:
- **LLVM**: C/C++ 컴파일러 (vcpkg 의존성 빌드용)
- **create-dmg**: macOS DMG 패키지 생성
- **pkg-config**: 라이브러리 경로 검색
- **cmake**: vcpkg 의존성 빌드
- **nasm**: 어셈블리 컴파일러 (aom, libjpeg-turbo 등)
- **CocoaPods**: macOS Flutter 플러그인 의존성 관리
- **Flutter 3.41.0**: UI 프레임워크

## 3. vcpkg 설정

```bash
git clone https://github.com/Microsoft/vcpkg.git ~/vcpkg
cd ~/vcpkg
git checkout 120deac3062162151622ca4860575a33844ba10b
./bootstrap-vcpkg.sh
```

## 4. CRLF 패치 파일 변환 (중요)

Windows에서 작성된 패치 파일이 CRLF 줄바꿈을 사용하면 macOS에서 ffmpeg 빌드가 실패합니다.
반드시 LF로 변환해야 합니다.

```bash
cd /path/to/onedesk
find res/vcpkg -name "*.patch" -exec perl -pi -e 's/\r\n/\n/g' {} +
find res/vcpkg -type f \( -name "*.cmake" -o -name "*.in" -o -name "*.json" -o -name "*.diff" \) -exec perl -pi -e 's/\r\n/\n/g' {} +
find res/vcpkg/ffmpeg/patch -name "*.patch" -exec perl -pi -e 's/\r\n/\n/g' {} +
```

## 5. vcpkg 의존성 설치

```bash
export VCPKG_ROOT=~/vcpkg
$VCPKG_ROOT/vcpkg install --x-install-root="$VCPKG_ROOT/installed"
```

설치되는 패키지:
- **aom**: AV1 비디오 코덱
- **ffmpeg**: 비디오 인코딩/디코딩 (VideoToolbox 하드웨어 가속 포함)
- **libjpeg-turbo**: JPEG 이미지 처리
- **libvpx**: VP8/VP9 비디오 코덱
- **libyuv**: YUV 이미지 변환
- **opus**: 오디오 코덱

## 6. Flutter-Rust 브릿지 생성

```bash
# 브릿지 도구 설치
cargo install cargo-expand --version 1.0.95 --locked
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features "uuid" --locked

# Flutter 의존성 설치 (extended_text 패치 필요)
cd flutter
sed -i '' -e 's/extended_text: 14.0.0/extended_text: 13.0.0/g' pubspec.yaml
flutter pub get
cd ..

# 브릿지 코드 생성
flutter_rust_bridge_codegen \
  --rust-input ./src/flutter_ffi.rs \
  --dart-output ./flutter/lib/generated_bridge.dart \
  --c-output ./flutter/macos/Runner/bridge_generated.h
```

## 7. macOS 프로젝트 설정 (중요)

빌드 전 아래 3가지 수정이 필요합니다.

### 7-1. CocoaPods xcconfig 연결

Flutter macOS 프로젝트에서 CocoaPods 플러그인이 제대로 링크되려면 xcconfig에 Pods 설정을 포함해야 합니다.

**`flutter/macos/Runner/Configs/Debug.xcconfig`:**
```
#include "../../Flutter/Flutter-Debug.xcconfig"
#include "Warnings.xcconfig"
#include "../../Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
```

**`flutter/macos/Runner/Configs/Release.xcconfig`:**
```
#include "../../Flutter/Flutter-Release.xcconfig"
#include "Warnings.xcconfig"
#include "../../Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"
```

### 7-2. sqflite 모듈 import 수정

`sqflite` 패키지가 `sqflite_darwin`으로 이름이 변경되었으므로 import를 수정합니다.

**`flutter/macos/Runner/MainFlutterWindow.swift`:**
```swift
// 변경 전
import sqflite
// 변경 후
import sqflite_darwin
```

### 7-3. 아키텍처 설정

**arm64 전용 빌드 (기본):** Rust 라이브러리가 arm64로만 빌드되므로, Xcode 프로젝트도 arm64만 타겟팅해야 합니다.

**`flutter/macos/Runner.xcodeproj/project.pbxproj`:**

3곳의 `ARCHS` 설정을 변경:
```
ARCHS = arm64;
```

**유니버셜 빌드:** x86_64 + arm64 유니버셜 PKG를 빌드하려면 아래의 "유니버셜 PKG 빌드" 섹션을 참조하세요. 이 경우 `ARCHS = "$(ARCHS_STANDARD)";`으로 설정합니다.

### 7-4. CocoaPods 설치

```bash
cd flutter/macos
pod install
cd ../..
```

## 8. VCPKG_ROOT 환경변수 설정

빌드 시 매번 `export`하지 않도록 쉘 프로필에 추가합니다.

```bash
# ~/.zshrc 또는 ~/.bashrc에 추가
echo 'export VCPKG_ROOT=~/vcpkg' >> ~/.zshrc
source ~/.zshrc
```

## 9. 빌드 실행

```bash
python3 ./build.py --flutter --hwcodec --unix-file-copy-paste --screencapturekit
```

PKG 설치 파일도 함께 생성하려면:
```bash
python3 ./build.py --flutter --hwcodec --unix-file-copy-paste --screencapturekit --pkg
```

빌드 옵션:
- `--flutter`: Flutter UI 사용
- `--hwcodec`: 하드웨어 비디오 코덱 (VideoToolbox)
- `--unix-file-copy-paste`: Unix 파일 클립보드 지원
- `--screencapturekit`: macOS ScreenCaptureKit 사용 (macOS 12.3+, aarch64 전용)
- `--pkg`: macOS PKG 설치 파일 생성 (`onedesk-1.4.4-aarch64.pkg`)
- `--skip-cargo`: Rust 빌드 건너뛰기 (Dart만 수정한 경우 유용)

빌드 과정:
1. Rust 라이브러리 컴파일 (`cargo build --release`) — 약 4분
2. Flutter macOS 앱 빌드 (`flutter build macos --release`)
3. service 바이너리를 앱 번들에 복사
4. (--pkg 옵션 시) PKG 설치 파일 생성

## 10. PKG 설치 (선택)

```bash
# GUI 설치
open onedesk-1.4.4-aarch64.pkg

# CLI 설치
sudo installer -pkg onedesk-1.4.4-aarch64.pkg -target /
```

## 11. DMG 생성 (선택)

```bash
create-dmg \
  --icon "OneDesk.app" 200 190 \
  --hide-extension "OneDesk.app" \
  --window-size 800 400 \
  --app-drop-link 600 185 \
  onedesk-1.4.4-aarch64.dmg \
  ./flutter/build/macos/Build/Products/Release/OneDesk.app
```

## 유니버셜 (x86_64 + arm64) PKG 빌드

Intel Mac과 Apple Silicon Mac 모두에서 동작하는 유니버셜 바이너리 PKG를 만들 수 있습니다.

### 사전 준비

```bash
# x86_64 Rust 타겟 설치
rustup target add x86_64-apple-darwin

# vcpkg x64-osx 의존성 설치 (프로젝트 디렉토리에서 실행)
cd /path/to/onedesk
export VCPKG_ROOT=~/vcpkg
$VCPKG_ROOT/vcpkg install --triplet x64-osx --x-install-root="$VCPKG_ROOT/installed"

# ffmpeg은 manifest mode에서 host-only로 설치되므로 classic mode로 별도 설치
cd /tmp
$VCPKG_ROOT/vcpkg install "ffmpeg[core]:x64-osx" \
  --overlay-ports=/path/to/onedesk/res/vcpkg \
  --x-install-root="$VCPKG_ROOT/installed"
```

### Xcode 프로젝트 아키텍처 설정

`flutter/macos/Runner.xcodeproj/project.pbxproj` 파일에서 3곳의 `ARCHS` 설정을 변경:
```
// arm64 전용 → 유니버셜
ARCHS = arm64;
// 변경 후
ARCHS = "$(ARCHS_STANDARD)";
```

### 빌드 절차

```bash
export VCPKG_ROOT=~/vcpkg

# 1. x86_64 Rust 빌드
MACOSX_DEPLOYMENT_TARGET=10.14 cargo build \
  --features flutter,hwcodec,unix-file-copy-paste,screencapturekit \
  --release --target x86_64-apple-darwin

# 2. aarch64 Rust 빌드
MACOSX_DEPLOYMENT_TARGET=10.14 cargo build \
  --features flutter,hwcodec,unix-file-copy-paste,screencapturekit \
  --release --target aarch64-apple-darwin

# 3. lipo로 유니버셜 바이너리 생성
mkdir -p target/universal-apple-darwin/release
lipo -create \
  target/x86_64-apple-darwin/release/liblibonedesk.dylib \
  target/aarch64-apple-darwin/release/liblibonedesk.dylib \
  -output target/universal-apple-darwin/release/liblibonedesk.dylib

lipo -create \
  target/x86_64-apple-darwin/release/service \
  target/aarch64-apple-darwin/release/service \
  -output target/universal-apple-darwin/release/service

# 4. 유니버셜 바이너리를 target/release에 복사 (build.py가 참조하는 경로)
cp target/universal-apple-darwin/release/liblibonedesk.dylib target/release/liblibonedesk.dylib
cp target/universal-apple-darwin/release/liblibonedesk.dylib target/release/libonedesk.dylib
cp target/universal-apple-darwin/release/service target/release/service

# 5. Flutter 빌드 + PKG 패키징 (--skip-cargo로 Rust 빌드 건너뛰기)
python3 build.py --flutter --hwcodec --unix-file-copy-paste --screencapturekit --pkg --skip-cargo

# 6. 파일명 변경 (aarch64 → universal)
mv onedesk-1.4.4-aarch64.pkg onedesk-1.4.4-universal.pkg
```

### 검증

빌드된 앱 번들의 바이너리가 유니버셜인지 확인:
```bash
file flutter/build/macos/Build/Products/Release/OneDesk.app/Contents/MacOS/OneDesk
# 출력: Mach-O universal binary with 2 architectures: [x86_64] [arm64]

file flutter/build/macos/Build/Products/Release/OneDesk.app/Contents/MacOS/service
# 출력: Mach-O universal binary with 2 architectures: [x86_64] [arm64]

file flutter/build/macos/Build/Products/Release/OneDesk.app/Contents/Frameworks/liblibonedesk.dylib
# 출력: Mach-O universal binary with 2 architectures: [x86_64] [arm64]
```

### 참고사항

- x86_64 빌드에서 `src/platform/macos.rs`의 `BOOL` 타입 차이 주의: arm64에서 `BOOL`은 `bool`, x86_64에서는 `i8` (`signed char`). `added != NO` 형태로 비교해야 양쪽 모두 컴파일됨.
- 전체 빌드 소요 시간: 약 10~15분 (Rust x86_64 ~2분, Rust aarch64 ~3분, Flutter ~3분, 패키징 ~1분)
- `--screencapturekit` 옵션은 macOS 12.3+ 전용이지만 x86_64에서도 빌드 가능 (런타임 체크)
- arm64 전용으로 되돌리려면 `ARCHS = arm64;`로 복원

## 빌드 결과물

- `.app` 번들: `flutter/build/macos/Build/Products/Release/OneDesk.app` (~60MB)
- arm64 PKG: `onedesk-1.4.4-aarch64.pkg` (기본 빌드 시)
- 유니버셜 PKG: `onedesk-1.4.4-universal.pkg` (유니버셜 빌드 시)
- DMG 패키지: `onedesk-1.4.4-aarch64.dmg` (DMG 생성 시)

## 환경 변수 요약

| 변수 | 값 | 설명 |
|------|-----|------|
| VCPKG_ROOT | ~/vcpkg | vcpkg 설치 경로 |
| MAC_RUST_VERSION | 1.81 | macOS용 Rust 버전 |
| FLUTTER_VERSION | 3.41.0 | Flutter 버전 |
| VCPKG_COMMIT_ID | 120deac3... | vcpkg 커밋 해시 |

## 트러블슈팅

### VCPKG_ROOT 미설정 (`called Result::unwrap() on an Err value: NotPresent`)
hwcodec 빌드 시 `VCPKG_ROOT` 환경변수가 없으면 발생합니다. 8단계에서 쉘 프로필에 추가했는지 확인하세요.
```bash
echo $VCPKG_ROOT  # ~/vcpkg 가 출력되어야 함
```

### ffmpeg 헤더 누락 (`'libavcodec/avcodec.h' file not found`)
vcpkg에 ffmpeg이 설치되지 않았거나 불완전한 경우 발생합니다. 프로젝트의 커스텀 portfile로 재설치하세요.
```bash
cd /path/to/onedesk
rm -rf $VCPKG_ROOT/installed/arm64-osx/lib/libav* $VCPKG_ROOT/installed/arm64-osx/include/libav*
$VCPKG_ROOT/vcpkg install --x-install-root="$VCPKG_ROOT/installed"
```
> **주의**: `vcpkg install "ffmpeg[...]:arm64-osx"` 명령으로 직접 설치하면 안 됩니다.
> 프로젝트의 커스텀 portfile(`res/vcpkg/ffmpeg/portfile.cmake`)이 무시되어
> swresample 링킹 오류가 발생합니다. 반드시 `vcpkg install` (매니페스트 모드)을 사용하세요.

### ffmpeg 빌드 실패 (configure syntax error)
패치 파일의 CRLF 줄바꿈이 원인입니다. 4단계의 CRLF 변환을 실행하세요.

### Rust 버전 오류
macOS는 Rust 1.81이 필요합니다. `rustup default 1.81.0`으로 설정하세요.

### ScreenCaptureKit 오류
macOS 12.3 미만이거나 x86_64에서는 `--screencapturekit` 옵션을 제거하세요.

### sqflite 모듈 오류 (Unable to find module dependency: 'sqflite')
`sqflite` 패키지가 `sqflite_darwin`으로 변경되었습니다. 7-2 단계를 참조하세요.

### x86_64 링크 오류 (Undefined symbols for architecture x86_64)
Rust 라이브러리가 arm64 전용으로 빌드되었기 때문입니다. 7-3 단계에서 `ARCHS = arm64`로 설정하세요.

### CocoaPods 플러그인 미인식
`flutter/macos/Runner/Configs/` 의 xcconfig 파일에 Pods 설정이 포함되어야 합니다. 7-1 단계를 참조하세요.

### swresample 링킹 오류 (`Undefined symbols: _swr_alloc, _swr_convert ...`)
`vcpkg install "ffmpeg[...]:arm64-osx"` 명령으로 ffmpeg을 직접 설치한 경우 발생합니다.
프로젝트의 커스텀 portfile은 `--disable-swresample`로 빌드하는데, 레지스트리 기본 portfile은
swresample을 포함합니다. ffmpeg 헤더 누락 트러블슈팅 항목을 참고하여 커스텀 portfile로 재설치하세요.

### Dart 코드 변경이 반영되지 않을 때
Flutter 소스(.dart) 수정 후 빌드해도 변경이 반영되지 않으면 Flutter 캐시 문제입니다.
```bash
cd flutter && flutter clean && cd ..
python3 ./build.py --flutter --hwcodec --unix-file-copy-paste --screencapturekit --skip-cargo
```
`--skip-cargo`는 Rust 빌드를 건너뛰고 Flutter만 다시 빌드합니다. Dart만 수정한 경우 유용합니다.
