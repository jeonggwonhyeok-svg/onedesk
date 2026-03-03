# OneDesk iOS TestFlight 업로드 가이드

## 인증서/프로파일 정보

- **팀 ID**: `UBQCW2P8G4` (CoreSolution Co., Ltd)
- **번들 ID**: `com.carriez.flutterHbb.onedesk`
- **App Store Connect 앱 이름**: `OneDesk Remote Desktop` (ID: 6759941913)
- **인증서**: `Apple Distribution: CoreSolution Co., Ltd (UBQCW2P8G4)`
- **프로파일 이름**: `com.carriez.flutterHbb.onedesk AppStore`
- **exportOptions.plist**: `flutter/ios/exportOptions.plist`

---

## 로컬에서 빌드 + TestFlight 업로드

### 사전 조건 (최초 1회)

인증서와 프로파일이 Mac에 설치되어 있어야 합니다.

```bash
# 인증서 확인
security find-identity -v -p codesigning | grep "UBQCW2P8G4"
# → "Apple Distribution: CoreSolution Co., Ltd (UBQCW2P8G4)" 가 보이면 OK

# 프로파일 확인
ls ~/Library/MobileDevice/Provisioning\ Profiles/ | grep onedesk
# → onedesk-ios-prod-app-store.mobileprovision 이 보이면 OK
```

없으면 아래 명령으로 다운로드:

```bash
mkdir -p /tmp/onedesk-certs

# 프로파일 다운로드
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=cjez-qyjg-rsuy-omyo \
fastlane sigh \
  --username rncpeoples@icloud.com \
  --team-id UBQCW2P8G4 \
  --app-identifier com.carriez.flutterHbb.onedesk \
  --output-path /tmp/onedesk-certs \
  --filename onedesk-ios-prod-app-store.mobileprovision \
  --skip_install

# 프로파일 설치
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
cp /tmp/onedesk-certs/onedesk-ios-prod-app-store.mobileprovision \
   ~/Library/MobileDevice/Provisioning\ Profiles/
```

### 1단계: IPA 빌드

```bash
cd flutter
flutter build ipa --release --export-options-plist=ios/exportOptions.plist
```

성공하면:
```
✓ Built IPA to build/ios/ipa (43.8MB)
```

### 2단계: TestFlight 업로드

```bash
xcrun altool --upload-app --type ios \
  -f flutter/build/ios/ipa/*.ipa \
  -u rncpeoples@icloud.com \
  -p cjez-qyjg-rsuy-omyo
```

성공하면:
```
UPLOAD SUCCEEDED with no errors
```

### 3단계: 확인

업로드 후 5~15분 뒤 [App Store Connect](https://appstoreconnect.apple.com) →
**앱** → **OneDesk Remote Desktop** → **TestFlight** 탭에서 빌드 확인.

---

## GitHub Actions 자동 빌드

### 아키텍처

```
flutter-nightly.yml (trigger)
  └→ flutter-build.yml (build-onedesk-ios job)
       ├─ 인증서 설치 (Keychain)
       ├─ 프로비저닝 프로파일 설치
       ├─ flutter build ipa --release
       └─ apple-actions/upload-testflight-build@v3
```

### 수동 트리거

```bash
gh workflow run flutter-nightly.yml --ref master
```

### 자동 트리거
- 매일 자정 (UTC 00:00) 자동 실행

### 필요한 GitHub Secrets

레포지토리 → Settings → Secrets and variables → Actions 에서 관리

| Secret 이름 | 설명 | 갱신 주기 |
|---|---|---|
| `APPLE_ID` | `rncpeoples@icloud.com` | 변경 시 |
| `APPLE_APP_SPECIFIC_PASSWORD` | appleid.apple.com 앱 전용 암호 | 만료 시 |
| `FASTLANE_SESSION` | fastlane 인증 세션 쿠키 | **30일마다 갱신 필요** |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Apple Distribution 인증서 (.p12, base64) | 1년마다 |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | .p12 내보내기 비밀번호 (현재 빈 값) | 변경 시 |
| `IOS_PROVISIONING_PROFILE_BASE64` | App Store 프로비저닝 프로파일 (.mobileprovision, base64) | 1년마다 |

---

## FASTLANE_SESSION 갱신 (30일마다)

세션이 만료되면 GitHub Actions 빌드에서 인증 오류가 발생합니다.

```bash
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=cjez-qyjg-rsuy-omyo \
fastlane spaceauth -u rncpeoples@icloud.com
```

출력된 세션 문자열을 `FASTLANE_SESSION` GitHub Secret에 업데이트.

---

## 인증서 만료 시 재생성 (1년마다)

```bash
mkdir -p /tmp/onedesk-certs

# 1. 새 인증서 생성
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=cjez-qyjg-rsuy-omyo \
fastlane cert \
  --username rncpeoples@icloud.com \
  --team-id UBQCW2P8G4 \
  --output-path /tmp/onedesk-certs

# 2. 새 프로파일 생성
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=cjez-qyjg-rsuy-omyo \
fastlane sigh \
  --username rncpeoples@icloud.com \
  --team-id UBQCW2P8G4 \
  --app-identifier com.carriez.flutterHbb.onedesk \
  --output-path /tmp/onedesk-certs \
  --filename onedesk-ios-prod-app-store.mobileprovision \
  --skip_install

# 3. GitHub Secrets 업데이트
CERT_B64=$(base64 -i /tmp/onedesk-certs/*.p12)
PROFILE_B64=$(base64 -i /tmp/onedesk-certs/onedesk-ios-prod-app-store.mobileprovision)
gh secret set IOS_DISTRIBUTION_CERTIFICATE_BASE64 --body "$CERT_B64"
gh secret set IOS_PROVISIONING_PROFILE_BASE64 --body "$PROFILE_B64"

# 4. 로컬 프로파일도 업데이트
cp /tmp/onedesk-certs/onedesk-ios-prod-app-store.mobileprovision \
   ~/Library/MobileDevice/Provisioning\ Profiles/
```

---

## 문제 해결

### `No Account for Team` 오류
→ exportOptions.plist의 teamID가 `UBQCW2P8G4`인지 확인.

### `No signing certificate iOS Distribution found` 오류
→ 키체인에 `Apple Distribution: CoreSolution Co., Ltd (UBQCW2P8G4)` 인증서가 있는지 확인:
```bash
security find-identity -v -p codesigning | grep UBQCW2P8G4
```

### GitHub Actions 인증 오류
→ `FASTLANE_SESSION` 만료. 위의 갱신 방법 참고.

### App Store Connect에서 빌드가 안 보임
→ 업로드 후 처리 시간 필요 (보통 5~30분). 이메일로 처리 완료 알림이 옵니다.
