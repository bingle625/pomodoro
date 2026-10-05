# 자동 업데이트와 릴리스

## 사용자 동작

v1.1.0부터 Sparkle2.10.0으로 업데이트를 확인합니다. 기본 확인 주기는1시간이며 자동 확인·자동 다운로드/설치가 기본으로 켜져 있습니다. 설정의 ‘앱 업데이트’에서 각각 끌 수 있고, 설정의 ‘지금 확인’ 또는 앱 메뉴의 ‘업데이트 확인…’으로 수동 확인할 수 있습니다. 변경은 즉시 Sparkle 설정에 저장됩니다.

설치와 재시작은 타이머가 준비 상태이고, 저장 오류·저장 대기·미작성 메모가 없으며 메모/설정/작업 편집 창이 닫혔을 때 진행합니다. 집중·휴식 실행과 일시정지 중에는 다운로드한 업데이트를 보류합니다. 설치 대기 중 자동 설치를 끄면 앱이 스스로 재시작하지 않으며, 명시적으로 요청한 설치는 이 설정과 별도로 처리됩니다. 설치를 시작한 순간부터 새 타이머·작업·메모 편집을 막고, 업데이트가 실패하거나 취소되면 다시 사용할 수 있게 합니다. 사용자가 직접 종료하면 이미 저장된 세션은 다음 실행에서 복원되고 Sparkle은 다운로드한 업데이트를 종료 시 설치할 수 있습니다.

v1.0.0에는 업데이트 기능이 없습니다. v1.1.0을 한 번 직접 다운로드해 Applications에 설치해야 이후 자동 업데이트를 받을 수 있습니다. 읽기 전용 DMG 안에서 실행하지 말고 설치 후 실행하세요.

## 배포 구조

- 버전: `Packaging/Info.plist`의 CFBundleShortVersionString과 CFBundleVersion을 함께 증가시킵니다.
- 고정 피드 주소: `https://github.com/bingle625/pomodoro/releases/latest/download/appcast.xml`
- 업데이트 파일: 같은 정식 릴리스의 `Pomodoro-<version>-arm64.dmg`
- 검증: SUPublicEDKey, SUVerifyUpdateBeforeExtraction, SURequireSignedFeed로 업데이트 파일과 목록 모두를 검증합니다.
- 설정은 Sparkle의 UserDefaults, 집중 기록은 기존 JSON에 보관합니다. 이번 버전은 JSON 스키마를 바꾸지 않습니다.

태그나 소스 코드만 올려서는 업데이트되지 않습니다. **매 정식 릴리스에 서명한 DMG와 appcast.xml을 함께 첨부**해야 합니다. `latest`가 가리키는 릴리스에 appcast가 없으면 업데이트 확인이 실패합니다.

## 서명키

개인키는 개발 Mac의 로그인 Keychain에 Sparkle 계정 이름 `local.pomodoro.app`으로 보관합니다. 공개키만 Info.plist에 들어 있습니다. 개인키를 저장소·릴리스 파일·로그에 출력하거나 커밋하지 않습니다. 현재 GitHub Actions에 개인키를 전달하지 않으므로 릴리스 서명은 이 Mac에서 수행합니다.

키를 잃으면 기존 설치본이 새 서명을 신뢰할 수 없으므로 키체인 백업을 유지해야 합니다. 새 Mac에서는 Sparkle 공식 키 이전 절차를 따르세요. 빌드 스크립트는 키체인 공개키와 앱 공개키가 다르면 중단합니다.

Ed25519 업데이트 서명은 Apple Developer ID 코드 서명·공증과 별개입니다. 현재 .app은 ad-hoc 서명으로 배포하며, 다른 Mac에서의 최초 실행은 macOS 보안 정책에 따라 제한될 수 있습니다.

## 새 버전 배포 순서

1. 앱 코드를 변경하고 Info.plist의 표시 버전과 빌드 번호를 증가시킵니다.
2. `swift test`를 실행합니다.
3. `bash scripts/build-release.sh`를 실행합니다. DMG·서명된 appcast·SHA256SUMS가 `dist/releases/v<version>/`에 생성됩니다. 이미 같은 DMG가 있으면 덮어쓰지 않고 중단합니다.
4. 앱 빌드와 설치 보류 동작, DMG와 피드 서명을 확인합니다. 자동 생성된 appcast를 수정했다면 반드시 다시 서명해야 합니다.
5. 소스를 커밋하고 main에 푸시합니다. 해당 커밋으로 GitHub 초안 릴리스를 생성하고 DMG·appcast.xml·SHA256SUMS.txt를 첨부합니다.
6. 첨부 파일이 모두 준비된 뒤 초안을 정식 릴리스로 공개합니다. 최신 피드 URL과 다운로드 파일의 체크섬을 확인합니다.

Sparkle 배포 도구는 고정된 SPM 아티팩트의 `.build/artifacts/sparkle/Sparkle/bin/`에 있습니다. 앱과 업데이트 목록의 서명 무결성 검사는 `sign_update --account local.pomodoro.app --verify ...`를 사용합니다.

## 검증 범위

설치 보류의 각 조건과 재개 시1회 실행, 취소된 콜백 폐기를 Core 테스트로 검증합니다. SwiftUI/AppKit 실제 화면 조작은 기존 Computer Use 접근 거절 때문에 자동 검증하지 못했습니다. 실제 설치본이 미래 버전으로 교체되고 재실행되는 전체 경로와 다른 Mac의 Gatekeeper 동작은 별도 실기기 검증이 필요합니다.
