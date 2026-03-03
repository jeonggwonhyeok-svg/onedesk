# OneDesk iOS TestFlight 자동 업로드 가이드

GitHub Actions에서 iOS IPA를 빌드하고 TestFlight에 자동 업로드하는 방법을 설명합니다.

## 아키텍처

```
flutter-nightly.yml (trigger)
  └→ flutter-build.yml (build-onedesk-ios job)
       ├─ 인증서 설치 (Keychain)
       ├─ 프로비저닝 프로파일 설치
       ├─ flutter build ipa --release
       └─ apple-actions/upload-testflight-build@v3
```

## 필요한 GitHub Secrets

레포지토리 → Settings → Secrets and variables → Actions 에서 관리

| Secret 이름 | 설명 | 갱신 주기 |
|---|---|---|
| `APPLE_ID` | Apple ID 이메일 (`rncpeoples@icloud.com`) | 변경 시 |
| `APPLE_APP_SPECIFIC_PASSWORD` | [appleid.apple.com](https://appleid.apple.com) 앱 전용 암호 | 만료 시 |
| `FASTLANE_SESSION` | fastlane 인증 세션 쿠키 | **30일마다 갱신 필요** |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Apple Distribution 인증서 (.p12, base64) | 1년마다 |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | .p12 내보내기 비밀번호 | 변경 시 |
| `IOS_PROVISIONING_PROFILE_BASE64` | App Store 프로비저닝 프로파일 (.mobileprovision, base64) | 1년마다 |

## 빌드 트리거 방법

### 수동 트리거 (즉시 빌드)
```bash
gh workflow run flutter-nightly.yml --ref master
```

### 자동 트리거
- 매일 자정(UTC 00:00) 자동 실행

## FASTLANE_SESSION 갱신 방법 (30일마다)

세션이 만료되면 빌드에서 인증 오류가 발생합니다. 아래 명령어로 갱신하세요.

```bash
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=<앱전용암호> \
fastlane spaceauth -u rncpeoples@icloud.com
```

출력된 세션 문자열을 `FASTLANE_SESSION` GitHub Secret에 업데이트하세요.

## 인증서/프로파일 정보

- **팀 ID**: `HZF9JMC8YN`
- **번들 ID**: `com.carriez.flutterHbb.onedesk`
- **인증서 ID**: `N92GQHZT45` (Apple Distribution)
- **프로파일 이름**: `com.carriez.flutterHbb.onedesk AppStore`
- **exportOptions.plist**: `flutter/ios/exportOptions.plist`

## 인증서 만료 시 재생성

인증서는 **1년** 후 만료됩니다. 만료 시 아래 명령어로 재생성하세요.

```bash
# 1. 새 인증서 생성
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=<앱전용암호> \
FASTLANE_SESSION='<세션값>' \
fastlane cert --username rncpeoples@icloud.com --team-id HZF9JMC8YN --output-path /tmp/onedesk-certs

# 2. 새 프로파일 생성
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=<앱전용암호> \
FASTLANE_SESSION='<세션값>' \
fastlane sigh \
  --username rncpeoples@icloud.com \
  --team-id HZF9JMC8YN \
  --app-identifier com.carriez.flutterHbb.onedesk \
  --output-path /tmp/onedesk-certs \
  --filename onedesk-ios-prod-app-store.mobileprovision \
  --skip_install

# 3. GitHub Secrets 업데이트
CERT_B64=$(base64 -i /tmp/onedesk-certs/*.p12)
PROFILE_B64=$(base64 -i /tmp/onedesk-certs/onedesk-ios-prod-app-store.mobileprovision)
gh secret set IOS_DISTRIBUTION_CERTIFICATE_BASE64 --body "$CERT_B64"
gh secret set IOS_PROVISIONING_PROFILE_BASE64 --body "$PROFILE_B64"
```

## 문제 해결

### 업로드 실패: 인증 오류
→ `FASTLANE_SESSION` 만료. 위의 갱신 방법 참고.

### 빌드 실패: 코드 사이닝 오류
→ 인증서 또는 프로파일 만료. 위의 재생성 방법 참고.

### App Store Connect에서 빌드가 안 보임
→ 업로드 후 처리 시간이 필요합니다 (보통 5~30분).
