# 검증 기록

## 환경

2026-10-05, Apple Silicon Mac, Xcode 설치 Swift6.4. 배포 최소 버전은 macOS14다. Swift Package의 Core 테스트와 SwiftUI/AppKit 앱을 같은 저장소에서 빌드했다.

## 확인한 내용

- `swift test`: 22개 XCTest 성공, 실패0.
- `swift build`: debug 앱 컴파일 성공.
- `bash scripts/build-app.sh`: release 빌드와 .app 구성·로컬 서명 성공.
- `codesign --verify --deep --strict dist/Pomodoro.app`: 종료코드0.
- 임시 저장소 `/tmp/pomodoro-ui-check/state.json`으로 실제 앱 프로세스 실행. 앱 로그 오류 없이 상태 파일 생성 및 실행 중 세션 저장 확인.
- `git diff --check`: 공백 오류 없음.

Core 테스트는 기본 사이클, 일시정지 제외, 늦은 복귀 시 한 건 완료, 자연 완료 중복 방지, 부분 종료/0초 종료, 실행/일시정지 상태 왕복, JSON 저장·복원, 손상 파일·미지원 버전 보존, 잘못된 저장 거부, 집중/휴식 메모 구분, 저장 실패 재시도, 메모 대기열 귀속, 재실행 중복 방지, 작업 관리 제약과 설정 범위, 기간 끝 배제, DST·윤년·월요일 경계, 날짜를 넘긴 집중의 귀속, 시간 표시와 다이얼 각도를 포함한다.

## 실제 UI 검증 제한

Computer Use 도구가 Pomodoro 접근을 ‘Computer Use was not approved to use Pomodoro’로 거절했다. 따라서 자동 화면 조작·캡처를 수행하지 못했고, 다음 항목은 실기기 확인이 남아 있다.

- 참고 이미지와 실제 배치 비교, 작은 창·긴 한국어 메모·포커스 잘림
- 메모 입력·저장·건너뛰기와 일·주·월 회고 조작
- 플로팅 창의 다른 Space·전체화면·모니터 분리 동작
- 실제 잠자기·깨우기와 Dock 재열기
- 종소리 청감·음량과 설정 미리 듣기
- VoiceOver와 키보드 조작

앱 프로세스가 실행되었다는 사실을 위 UI 항목의 통과로 간주하지 않는다. macOS14 및 Intel Mac에서의 실행, 공증·외부 배포도 검증하지 않았다.

## 코드 리뷰와 수정

독립 리뷰에서 핵심 타이머·원자적 저장·메모 귀속·날짜 집계의 중요 결함은 발견되지 않았다. 넓은 화면에서 히트맵 행이 고정 높이를 초과하는 문제는 폭에 비례한 높이로 수정했다. 작업 편집·설정의 저장 재시도와 접근성 레이블도 보완했다.

사용자가 플로팅 창이 움직이지 않는 현상을 보고했다. 배경 이동 옵션에만 의존하던 구현을 바꾸어 다이얼과 상단 제목의 NSView가 원래 mouseDown 이벤트를 `NSWindow.performDrag(with:)`에 전달하게 했다. 비활성 창의 첫 클릭도 받는다. Apple의 [창 드래그 API 문서](https://developer.apple.com/documentation/appkit/nswindow/performdrag(with:))와 로컬 SDK 선언을 확인했다. 수정 후 Core22개 테스트가 성공했으며, 실제 마우스 드래그 재검증은 Computer Use 접근 거절로 수행하지 못했다.

사용자 요청에 따라 히트맵을 최근 주/월이 왼쪽인 순서로 바꾸고 월 레이블을 추가했다. 미래 날짜를 비우며 월~일 순서로 정렬한다. 연도 경계와 DST를 포함한2개 테스트를 추가했다.
