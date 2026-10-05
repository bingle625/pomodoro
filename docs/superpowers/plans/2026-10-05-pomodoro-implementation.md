# Mac Pomodoro Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mac에서 집중·휴식 타이머, 플로팅 다이얼, 집중 종료 메모와 회고 대시보드를 사용할 수 있는 로컬 앱을 완성한다.

**Architecture:** Foundation 기반 `PomodoroCore`가 상태 전이·저장·집계를 담당하고, `PomodoroApp`이 SwiftUI 화면과 AppKit 창·오디오를 담당한다. 단일 AppStore를 모든 창이 공유하며, 기록·현재 타이머·메모 대기열을 하나의 스냅샷으로 저장한다. 타이머의 현재 시각과 저장소를 주입해 실제 대기 없이 동작을 검증한다.

**Tech Stack:** Swift Package Manager, SwiftUI, AppKit, Foundation, Swift Charts, AVFoundation, XCTest. 외부 패키지 없음.

**Spec:** [기능 설계](../specs/2026-10-05-pomodoro-design.md), [시각 디자인](../../../Design.md). 두 문서를 함께 읽고 구현한다.

## Global Constraints

- macOS 14 이상을 대상으로 한다.
- 외부 패키지 없이 시스템 프레임워크를 사용한다.
- 앱 UI 언어는 한국어다.
- 집중 시간 기본 25분, 휴식 시간 기본 5분. 각각 1~60분으로 설정한다.
- 다음 단계 자동 시작(기본 꺼짐)을 제공한다.
- 일시정지 시간은 집중 시간에서 제외한다.
- 휴식 시간은 집중 통계에서 제외한다.
- 날짜 경계를 넘긴 세션은 시작한 날짜에 귀속한다.
- 초기 버전은 참고 이미지의 밝은 테마를 기준으로 한다.
- 가짜 기록과 임의 수치를 넣지 않는다.
- 초기 전달은 로컬 실행용이며 App Store 배포와 공증은 범위 밖이다.

## Review Focus

1. 잠자기·앱 종료 후 몇 시간이 지나 돌아와도 완료 기록은 한 건이며 자동 단계가 소급 생성되지 않는다. Task 1, 3에서 검증한다.
2. 저장 실패·손상 파일·미지원 데이터 버전이 기존 기록을 덮어쓰거나 메모를 잃게 하지 않는다. Task 2, 3에서 검증한다.
3. 메모 작성 중 다음 집중이 끝나도 메모는 원래 세션에 저장되고 새 세션은 대기열에 남는다. Task 3, 6에서 검증한다.
4. 월말·월요일·DST 변경일과 정확한 기간 끝 시각에서 기록이 중복 집계되거나 누락되지 않는다. Task 4에서 검증한다.
5. 긴 한국어 메모, 작은 창, 보조 모니터 분리, 키보드 조작에서도 내용·컨트롤에 접근할 수 있다. Task 5~8에서 실제 UI로 검증한다.

## 파일 구성과 구현 결정

현재 저장소에는 설계 문서만 있다. 아래 파일은 모두 새로 만든다. 기존 `Design.md`를 구현 중 임의로 바꾸지 않는다.

| 경로 | 책임 |
|---|---|
| `Package.swift`, `.gitignore` | Core 라이브러리, App 실행 타깃, CoreTests 타깃; 빌드·배포 산출물 제외 |
| `Sources/PomodoroCore/Models.swift` | 작업·설정·기록·타이머·저장 스냅샷 값 타입 |
| `Sources/PomodoroCore/TimerEngine.swift` | 시각을 입력받는 순수 상태 전이 |
| `Sources/PomodoroCore/LocalRepository.swift` | 버전 검증과 원자적 JSON 저장 |
| `Sources/PomodoroCore/AppStore.swift` | 관찰 가능한 단일 앱 상태, 변경 저장, 완료 효과 |
| `Sources/PomodoroCore/Statistics.swift` | 기간·작업별 집계와 날짜 그룹 |
| `Sources/PomodoroCore/TimeFormatting.swift` | 숫자·시각·시간 문자열 및 다이얼 각도 |
| `Sources/PomodoroApp/PomodoroApp.swift`, `AppDelegate.swift` | 진입점, 주기 갱신, 재활성화, 종료·Dock 재열기 |
| `Sources/PomodoroApp/Design/Theme.swift`, `Components.swift` | Design.md 토큰, 카드·버튼·빈 상태 |
| `Sources/PomodoroApp/Main/MainView.swift`, `TaskEditor.swift`, `TimerBar.swift` | 사이드바·탭·작업 편집·타이머 제어 |
| `Sources/PomodoroApp/Timer/TimerDial.swift`, `FloatingTimerView.swift` | 부채꼴·눈금·플로팅 제어 |
| `Sources/PomodoroApp/Windows/WindowCoordinator.swift` | 메인·플로팅·메모 창 수명과 표시 |
| `Sources/PomodoroApp/Memo/MemoView.swift`, `Settings/SettingsView.swift` | 메모 작성·수정과 시간·소리 설정 |
| `Sources/PomodoroApp/Audio/BellPlayer.swift`, `Resources/bell.wav` | 짧은 종소리와 번들 리소스 |
| `Sources/PomodoroApp/Dashboard/SummaryView.swift`, `ActivityHeatmap.swift`, `FocusCharts.swift` | 요약·히트맵·막대·도넛 |
| `Sources/PomodoroApp/Review/ReviewView.swift`, `DaySection.swift` | 날짜별 회고 타임라인 |
| `Tests/PomodoroCoreTests/{TimerEngine,LocalRepository,AppStore,Statistics,TimeFormatting}Tests.swift` | 동작 테스트 |
| `Tests/PomodoroCoreTests/TestSupport.swift` | 고정 시각·메모리 저장소·저장 실패 주입 |
| `scripts/build-app.sh`, `scripts/generate-bell.py`, `Packaging/Info.plist` | 재현 가능한 .app 패키징과 음원 생성 |
| `README.md`, `docs/verification.md` | 실행 방법·검증 결과와 제한 |

**공통 타입:** 모든 ID는 UUID, 시각은 Date, 시간은 초 단위 TimeInterval로 통일한다. `FocusTask(id, name, colorHex)`, `Preferences(focusMinutes=25, breakMinutes=5, soundEnabled=true, autoStart=false)`, `FocusRecord(id, taskID, startedAt, endedAt, focusedSeconds, completed, memo)`를 Codable 값 타입으로 정의한다. `TimerPhase`는 focus/rest, `TimerStatus`는 ready/running/paused다.

`TimerState`에는 phase, status, sessionID, taskID, startedAt, durationSeconds, remainingSeconds, deadline을 저장한다. 실행 중 remainingSeconds는 체크포인트 값이며 표시에는 deadline을 사용한다. `AppSnapshot(schemaVersion=1, tasks, selectedTaskID, preferences, timer, records, pendingMemoIDs)`을 저장 단위로 한다.

**이번 계획에서 확정할 세부 동작:** 중도 종료는 다음 집중 준비로 돌아가며 완료 종소리를 내지 않는다. 일시정지 중에도 작업 변경은 막는다. 준비 상태의 시간 설정은 즉시 반영하고 실행·일시정지 상태는 기존 길이를 유지한다. 통계는 초를 합산한 뒤 분 단위 표시를 내림하며 평균도 실제 초 기준이다. 비교 기간은 이전 달력상의 하루·주·월 전체다. 작업 삭제는 확인 후 연결된 기록과 메모 대기열도 함께 삭제하며 진행 중인 세션의 작업은 삭제할 수 없다.

## Task 1: 테스트 가능한 타이머 엔진

**Files:** `Package.swift`, `.gitignore`, `Sources/PomodoroCore/{Models,TimerEngine}.swift`, `Tests/PomodoroCoreTests/{TimerEngineTests,TestSupport}.swift`.

**Interfaces:** `TimerEngine(state: TimerState)`, `remaining(at: Date) -> TimeInterval`, `start(taskID: UUID, preferences: Preferences, at: Date)`, `pause(at: Date)`, `resume(at: Date)`, `advance(at: Date, preferences: Preferences) -> TimerCompletion?`, `stop(at: Date, preferences: Preferences) -> TimerCompletion?`. 변경 메서드는 mutating이다. `TimerCompletion`은 sessionID, phase, taskID, startedAt, endedAt, focusedSeconds, completed를 가진다. AppStore가 저장과 효과를 담당하고 엔진은 I/O를 하지 않는다.

- [ ] Package에 Core와 XCTest 타깃을 설정하고 TimerEngineTests에 아래 실패 테스트를 작성한다. 앱 타깃은 Task 5에서 추가한다.

```swift
// 각 행은 독립된 테스트이며 t0는 고정 Date다.
// testDefaultCycle: start(t0); remaining(t0) == 1500
// testPauseExcludesTime: pause(t0+60); resume(t0+360); remaining(t0+420) == 1380
// testCompletionOnce: advance(t0+1500) != nil; advance(t0+1501) == nil
// testLateWake: advance(t0+7200) -> focusedSeconds == 1500, endedAt == t0+1500
// testAutoRestStartsNow: autoStart=true; advance(t0+7200); deadline == t0+7500
// testPartialStop: stop(t0+9) -> focusedSeconds == 9, completed == false
// testZeroStop: stop(t0) == nil; phase == .focus; status == .ready
// testRestCompletion: phase == .rest event; next phase == .focus
```

- [ ] `swift test --filter TimerEngineTests` 실행: 미구현 타입·메서드로 실패함을 확인한다.
- [ ] 위 인터페이스와 값 타입을 구현한다. tick으로 시간을 누적 차감하지 않고 deadline 차이를 사용한다. 자연 완료는 원래 deadline을 endedAt으로, 부분 종료는 종료 요청 시각을 사용한다. 늦게 도착한 advance 한 번은 이벤트 하나만 반환한다.
- [ ] 같은 테스트 실행: 모두 통과. Codable로 TimerState를 왕복한 뒤 실행·일시정지 복원 테스트도 통과시킨다.
- [ ] 해당 파일만 스테이징하고 `feat: add deterministic pomodoro timer engine`으로 커밋한다.

## Task 2: 손실을 방지하는 로컬 저장

**Files:** `Sources/PomodoroCore/LocalRepository.swift`, `Tests/PomodoroCoreTests/LocalRepositoryTests.swift`; Modify: `Models.swift`에 AppSnapshot 추가.

**Interfaces:** `SnapshotRepository { func load() throws -> AppSnapshot?; func save(_ snapshot: AppSnapshot) throws }`, `LocalRepository(fileURL: URL)`, `static defaultFileURL() throws -> URL`. 경로는 Application Support/Pomodoro/state.json. 파일 부재만 nil이며 다른 실패는 오류다.

- [ ] 테스트 작성: `testRoundTrip`은 작업·설정·진행 세션·메모 대기열·한국어/이모지/줄바꿈 메모가 동일함을 assert한다. `testCorruptFile`과 `testFutureSchema`는 load가 throw하고 원본 Data가 그대로임을 assert한다. `testSaveFailureKeepsOldFile`은 쓰기 실패 후 이전 유효 파일을 여전히 load할 수 있음을 assert한다. 임시 디렉터리만 사용한다.
- [ ] `swift test --filter LocalRepositoryTests`: 구현 전 실패를 확인한다.
- [ ] Codable JSON과 `.atomic` 쓰기를 구현한다. schemaVersion=1과 필수 참조·시간 범위를 검증하고 잘못된 데이터는 읽기 오류로 보고한다. 미래 버전을 조용히 초기화하지 않는다.
- [ ] 같은 테스트 실행: 모두 통과. 오류에 파일 경로와 사용자에게 표시할 원인을 포함한다.
- [ ] `feat: persist versioned app snapshots atomically` 커밋.

## Task 3: 앱 상태·작업 관리·완료 이벤트 연결

**Files:** `Sources/PomodoroCore/AppStore.swift`, `Tests/PomodoroCoreTests/AppStoreTests.swift`; Modify: `TestSupport.swift`.

**Interfaces:** `@MainActor @Observable AppStore(repository: any SnapshotRepository, now: @escaping () -> Date)`. `snapshot: AppSnapshot`, `storageError: String?`, `memoSessionID: UUID?`, `isReadOnly: Bool`. `load()`, `start()`, `pause()`, `resume()`, `stop()`, `tick()`, `retrySave()`, `selectTask(_ id: UUID)`, `addTask(name: String, colorHex: String)`, `updateTask(id: UUID, name: String, colorHex: String)`, `deleteTask(id: UUID)`, `updatePreferences(_ value: Preferences)`, `saveMemo(recordID: UUID, text: String)`, `skipMemo(recordID: UUID)`는 동기 throwing 연산이다. `onBell: (() -> Void)?`는 저장에 성공한 자연 완료를 알린다.

- [ ] 테스트 작성: testFirstLaunch는 기본 작업1개·기록0건, testFocusCompletion은 기록1건·동일 ID 메모 대기열·종소리1회, testRestHasNoRecordOrMemo는 집중 기록과 메모 수 불변을 assert한다.
- [ ] 실패 테스트 작성: testCompletionSaveRetry는 실패 시 종소리0회, 재시도 후1회·기록1건. testMemoQueueIdentity는 A입력 중 B완료 후 A저장이 A만 갱신하고 B를 대기열에 유지함을 검증한다. testReadOnlyAfterLoadError는 변경 불가·저장 호출0회, testRelaunchCompletedSession은 두 번 실행해도 기록1건을 assert한다.
- [ ] `swift test --filter AppStoreTests`: 미구현 상태의 실패를 확인한다.
- [ ] AppStore를 구현한다. 다음 snapshot을 저장한 후 공개한다. tick 표시는 저장하지 않고 상태 전이만 저장한다. 완료 저장 실패 시 다음 단계를 시작하지 않고 대기 변경을 유지한다. 저장 성공 후 종소리와 메모를 제공한다. load 실패 시 읽기 전용 오류 화면을 표시하고 초기값을 저장하지 않는다.
- [ ] CRUD 테스트를 추가한다. 공백 이름, 실행·일시정지 중 작업 변경/삭제, 마지막 작업 삭제를 거부한다. 정상 삭제는 관련 기록·대기열을 제거한다. 설정 0/61분은 거부하고 1/60분은 허용한다. 실행 중 설정 변경은 deadline을 유지하고 준비 상태는 즉시 반영함을 assert한다.
- [ ] 해당 테스트를 다시 실행해 모두 통과하는지 확인한다.
- [ ] `feat: coordinate sessions tasks and memo persistence` 커밋。

## Task 4: 기간 집계와 시간 표시

**Files:** `Sources/PomodoroCore/{Statistics,TimeFormatting}.swift`, `Tests/PomodoroCoreTests/{StatisticsTests,TimeFormattingTests}.swift`.

**Interfaces:** `Period: day/week/month`, `Statistics(calendar: Calendar)`, `interval(for: Period, containing: Date) -> DateInterval`, `summary(records: [FocusRecord], taskID: UUID?, interval: DateInterval) -> FocusSummary`, `days(records: [FocusRecord], taskID: UUID?, interval: DateInterval) -> [DayGroup]`, `taskTotals(records: [FocusRecord], interval: DateInterval) -> [UUID: TimeInterval]`. `FocusSummary(count, totalSeconds, averageSeconds)`, `DayGroup(date, records, totalSeconds)`. `TimeFormatting.countdown(_ seconds: TimeInterval) -> String`, `total(_ seconds: TimeInterval) -> String`, `recordMinutes(_ seconds: TimeInterval) -> String`, `dialDegrees(_ seconds: TimeInterval) -> Double`.

- [ ] 테스트 작성: 1500+540+300초는 3건·2340초·평균780초다. 기간 start는 포함하고 end는 제외한다. 23:55 시작한 25분은 시작일에 전부 귀속한다. 주 시작은 월요일, 빈 집합은 0건·평균0이다. 다른 작업이 섞이지 않으며 휴식은 FocusRecord로 생성되지 않는다.
- [ ] 경계 테스트 작성: 1월→전년12월, 윤년2월, Asia/Seoul의 월요일, America/Los_Angeles의 DST 변경일을 Calendar 날짜 연산으로 검증한다. 25분→150도, 5분→30도, 60분→360도, 0초→0도, 59초→‘1분 미만’, 1500초→‘25:00’, 8340초→합계‘02:19’를 assert한다.
- [ ] `swift test --filter 'StatisticsTests|TimeFormattingTests'`: 미구현 상태의 실패를 확인한다.
- [ ] 인터페이스를 구현한다. 기간은 `start <= startedAt && startedAt < end`다. 주 시작은 월요일로 고정하고 날짜 이동에 86400초를 더하지 않는다. countdown은 올림, 합계는 초를 더한 후 분으로 내림한다.
- [ ] 해당 테스트를 다시 실행해 모두 통과하는지 확인한다.
- [ ] `feat: aggregate focus history by calendar period` 커밋。

## Task 5: 네이티브 앱 구성과 메인 화면

**Files:** `Sources/PomodoroApp/{PomodoroApp,AppDelegate}.swift`, `Design/{Theme,Components}.swift`, `Main/{MainView,TaskEditor,TimerBar}.swift`, `Windows/WindowCoordinator.swift`, `scripts/build-app.sh`, `Packaging/Info.plist`; Modify: `Package.swift`.

**Interfaces: 미구현 상태의 실패를 확인한다.

- [ ] App 실행 타깃과 Bundle ID `local.pomodoro.app`의 Info.plist를 추가한다. build-app.sh는 release 빌드 후 `swift build --show-bin-path -c release` 경로의 실행 파일·리소스 bundle을 `dist/Pomodoro.app/Contents`에 배치하고 로컬 실행용 서명을 한다.
- [ ] Theme에 Design.md의 모든 토큰을 모으고 MainView·작업 추가/편집/삭제 확인·TimerBar를 구현한다. 최소 창 크기는760×600pt, 초기 크기는1160×820pt다. 760pt 미만 한 열 배치는 사이드바를 제외한 본문 폭으로 판단한다.
- [ ] AppDelegate에서 AppStore를 한 번 load하고 0.2초 간격으로 main actor에서 tick한다. wake/active에 즉시 tick하고 종료 전에 상태 저장을 시도한다. 메인 창을 닫아도 앱과 타이머는 유지하고 Dock에서 다시 열 수 있게 한다.
- [ ] `swift build`와 `swift test` 실행: 빌드와 기존 테스트가 모두 성공한다.
- [ ] `bash scripts/build-app.sh`로 .app을 생성하고 실제로 연다. 작업 추가·개명·삭제, 시작·일시정지·재개·중도 종료, 재시작 복원을 확인하고 Task 8 검증 기록에 남긴다. 긴 작업명과 키보드 포커스 잘림도 확인한다.
- [ ] `feat: add native application shell and timer controls` 커밋。

## Task 6: 플로팅 타이머·종료 메모·종소리·설정

**Files:** `Sources/PomodoroApp/` 아래 `Timer/{TimerDial,FloatingTimerView}.swift`, `Memo/MemoView.swift`, `Settings/SettingsView.swift`, `Audio/BellPlayer.swift`, `Resources/bell.wav`; `scripts/generate-bell.py`. Modify: `WindowCoordinator.swift`, `AppDelegate.swift`, `Package.swift`.

**Interfaces:** `TimerDial(remainingSeconds: TimeInterval, phase: TimerPhase)`, `FloatingTimerView(store: AppStore, windows: WindowCoordinator)`, `MemoView(store: AppStore, recordID: UUID)`, `SettingsView(store: AppStore, previewBell: () -> Void)`, `@MainActor BellPlayer.play() throws`. WindowCoordinator는 같은 store를 모든 NSHostingView에 전달한다.

- [ ] TimerDial을 Path와 눈금·숫자로 그린다. Task 4의 dialDegrees를 사용하고 0도는 비움, 360도는 원으로 처리한다. 320×360pt floating NSPanel에 일반 창 위 표시·Spaces 참여·전체화면 보조 설정, 배경 드래그, 닫기, 메인 열기를 구현한다. 위치를 저장하고 실행 시 연결된 화면의 visibleFrame 안으로 보정한다.
- [ ] MemoView는 recordID별 draft를 유지하고 ⌘Return은 저장, Return은 줄바꿈, 닫기는 skip으로 처리한다. 기존 기록 편집은 대기열을 불필요하게 소비하지 않는다. A를 저장/skip하고 B를 표시할 때 draft도 B로 전환한다. 자동 휴식 중 남은 시간을 표시한다.
- [ ] generate-bell.py에서 표준 라이브러리로 약0.7초의 감쇠하는 단발 벨 WAV를 생성한다. 음량에 여유를 두어 클리핑을 피하고 외부 음원에 의존하지 않는다. Bundle.module에서 BellPlayer로 재생하고 AppStore.onBell에 연결한다. 재생 실패는 시각적으로 알리고 완료 기록을 되돌리지 않는다.
- [ ] SettingsView에 1~60분 입력·Stepper, 소리 스위치·미리 듣기, autoStart 스위치를 구현한다. 편집 중 빈칸은 허용하되 확정 시 검증하여 잘못된 값을 저장하지 않는다. 메모 저장 실패는 draft를 유지하고 재시도할 수 있게 한다.
- [ ] `swift test`와 `bash scripts/build-app.sh` 실행: 모두 성공하고 생성된 .app에 bell 리소스가 포함되는지 확인한다.
- [ ] 일반 설정의1분 집중·1분 휴식으로 종료→메모→휴식 종료를 실행한다. 각 단계 종료 시 소리 한 번, 저장/skip, 메모 중 휴식 진행, 전체화면/다른 Space, 창 닫기 후 지속, 60/25/5/0분 다이얼을 확인한다. 실제로 소리를 듣지 못했다면 청감 미확인으로 기록한다.
- [ ] 테스트 전용 저장소로 저장 실패를 주입하고 A입력 중 B완료, 모니터 분리, VoiceOver 이름을 확인한다. 실패 주입과 테스트용 짧은 시간은 일반 사용자 설정에 노출하지 않는다.
- [ ] `feat: add floating timer session notes and bell` 커밋。

## Task 7: 요약·회고 대시보드

**Files:** `Sources/PomodoroApp/Dashboard/{SummaryView,ActivityHeatmap,FocusCharts}.swift`, `Review/{ReviewView,DaySection}.swift`; Modify: `MainView.swift`.

**Interfaces:** `SummaryView(store: AppStore)`, `ReviewView(store: AppStore, editMemo: (UUID) -> Void)`, `DaySection(group: DayGroup, expanded: Binding<Bool>, editMemo: (UUID) -> Void)`. 집계는 Task 4를 호출하고 View에서 중복 시간 계산을 구현하지 않는다.

- [ ] SummaryView에 오늘/이번 주/이번 달, 이전 기간 대비 증감, 평균, 누적을 구현한다. 히트맵은 오늘을 포함한 최근26주, 막대는 최근30일, 도넛은 선택 기간 전체 작업과 범례, 최근 메모는 선택 작업 최신5건이다. 데이터가 없으면0과 안내를 표시하고 도넛에 가짜 원호를 그리지 않는다.
- [ ] ReviewView에 일/주/월, 앞뒤 이동·오늘로 돌아가기, 기간 합계와 날짜 그룹을 구현한다. 날짜·시작 시각 내림차순, 최신 날짜 초기 펼침, 날짜 헤더 접기를 적용한다. 시작 시각→분→메모, 중단 배지, 빈 메모, 클릭 편집을 연결한다.
- [ ] 좁은 본문에서는 요약을 한 열로, 회고 시각을 카드 위쪽으로 옮긴다. 메모는3줄까지 표시하고 편집 창에서는 전문을 보여준다. 차트에 날짜·실제 시간 도움말과 접근성 정보를 붙인다.
- [ ] `swift test`와 `bash scripts/build-app.sh` 실행: 모두 성공. 테스트 전용 데이터3건/39분과4건/100분을 표시하여 합계7건/02:19를 확인한다. 독립된 임시 저장소만 사용하고 실제 사용자 데이터에 넣지 않는다.
- [ ] 760×600과1440×900pt에서200자 작업명·여러 줄1000자 한국어 메모·0건·날짜 경계를 확인한다. 메모 수정 즉시 반영, 기간 이동, 접기, 키보드와 VoiceOver 조작을 확인한다.
- [ ] `feat: add focus summary and reflection dashboard` 커밋。

## Task 8: 통합 검증과 로컬.app 전달

**Files:** `README.md`, `docs/verification.md`; 필요한 수정은 원인이 있는 파일에 한정한다.

- [ ] `swift test`, `swift build -c release`, `bash scripts/build-app.sh`, `git diff --check`를 실행하고 결과를 기록한다. `codesign --verify --deep --strict dist/Pomodoro.app`으로 번들 무결성을 확인한다. 이 검증은 공증이나 다른 Mac에서의 실행 보장이 아니다.
- [ ] 독립된 임시 저장소로 실제 앱을 열고 최초0건→작업 추가→집중→일시정지/재개→완료 메모→휴식→회고 편집→종료/재시작 흐름을 검증한다. 실제 저장소와 테스트 저장소를 명시하고 사용자 데이터를 삭제하지 않는다.
- [ ] 테스트 전용 저장소로 저장 실패를 주입하고 A입력 중 B완료, 모니터 분리, VoiceOver 이름을 확인한다. 실패 주입과 테스트용 짧은 시간은 일반 사용자 설정에 노출하지 않는다.
- [ ] 메인 요약·회고·플로팅·메모·설정 화면을 캡처하여 Design.md와 대조한다. 색상·숫자 폭·여백·잘림·포커스를 확인하고 문제가 있으면 수정한 뒤 해당 경로를 다시 검증한다.
- [ ] README에 빌드/실행·조작·저장소·Mac 요구사항·로컬 서명 범위를 쓴다. verification.md에는 명령 결과·실제 환경·수동 검증·미검증 제한을 쓴다. 확인하지 않은 OS나 소리 청감을 통과로 기록하지 않는다.
- [ ] 전체 구현을 기능 설계·Design.md·Review Focus와 대조해 리뷰한다. 발견한 결함을 수정하고 필요한 테스트를 재실행한다. 검증 문서는 `docs: document local app build and verification`으로 커밋한다.

## 실행 기록

2026-10-05: Task1~7 코드 구현 및 앱 빌드 완료. Core22개 테스트 통과. Task8의 실행 파일·사용 설명서·독립 코드 리뷰를 완료했으며 실제 UI 조작·캡처 검증은 Computer Use 접근 거절로 미완료다. 상세 증거와 제한은 [검증 기록](../../verification.md)을 따른다.

## 실행 방법과 완료 조건

Task 1→2→3→4→5→6→7→8 순서로 진행한다. Core와 각 창의 의존성이 밀접하므로 동일 세션에서 순차 구현을 권장한다.

필수 기능을 실제로 조작할 수 있고 Core 테스트가 성공하며 dist/Pomodoro.app, README, 검증 기록을 전달할 수 있으면 완료다.
