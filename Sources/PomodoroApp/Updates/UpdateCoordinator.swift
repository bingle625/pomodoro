import AppKit
import Observation
import Sparkle
import OSLog
import PomodoroCore

@MainActor @Observable final class UpdateCoordinator: NSObject, SPUUpdaterDelegate {
    private(set) var automaticallyChecks = true
    private(set) var automaticallyDownloads = true
    private(set) var canCheck = false
    private(set) var lastChecked: Date?
    private(set) var waitingMessage: String?
    let gate = UpdateInstallGate()
    @ObservationIgnored private var controller: SPUStandardUpdaterController!
    @ObservationIgnored private let store: AppStore
    @ObservationIgnored var hasOpenEditor: () -> Bool = { false }
    @ObservationIgnored var settingsState: () -> (open: Bool, dirty: Bool) = { (false, false) }
    @ObservationIgnored private var notice: NSAlert?
    private let logger = Logger(subsystem: "local.pomodoro.app", category: "Updates")
    var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "개발 버전" }

    init(store: AppStore) {
        self.store = store
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
    }
    func start() { controller.startUpdater(); synchronize() }
    func checkForUpdates() { guard controller.updater.canCheckForUpdates else { return }; controller.checkForUpdates(nil); synchronize() }
    func setAutomaticChecking(_ enabled: Bool) { controller.updater.automaticallyChecksForUpdates = enabled; synchronize() }
    func setAutomaticDownloading(_ enabled: Bool) { controller.updater.automaticallyDownloadsUpdates = enabled; synchronize() }
    private var safety: UpdateSafety {
        UpdateSafety(timerStatus: store.snapshot.timer.status, savePending: store.hasPendingSave,
                     readOnly: store.isReadOnly, memoPending: store.memoSessionID != nil, editorOpen: hasOpenEditor(),
                     settingsOpen: settingsState().open, settingsDirty: settingsState().dirty)
    }
    func synchronize() {
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        automaticallyDownloads = controller.updater.automaticallyDownloadsUpdates
        canCheck = controller.updater.canCheckForUpdates
        lastChecked = controller.updater.lastUpdateCheckDate
        let automaticEnabled = automaticallyChecks && automaticallyDownloads
        if gate.isPending && gate.isAutomaticPending && !automaticEnabled {
            waitingMessage = "업데이트를 다운로드했습니다. 자동 설치를 꺼 두어 앱을 종료할 때 설치합니다."
        } else {
            waitingMessage = gate.isPending ? (safety.blockingReason(automatic: gate.isAutomaticPending) ?? "업데이트를 설치합니다…") : nil
        }
        gate.process(safety, automaticInstallationEnabled: automaticEnabled)
    }
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        gate.deferInstallation(automatic: true) { [weak self] in
            self?.dismissNotice()
            self?.store.setUpdateInstallationInProgress(true)
            immediateInstallHandler()
        }
        return true
    }
    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem, untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard let reason = safety.blockingReason else {
            logger.info("Installing update: manual relaunch is safe")
            gate.cancel(); store.setUpdateInstallationInProgress(true); return false
        }
        logger.info("Postponing update: \(reason, privacy: .public)")
        waitingMessage = reason
        gate.deferInstallation { [weak self] in
            self?.dismissNotice()
            self?.store.setUpdateInstallationInProgress(true)
            installHandler()
        }
        // Sparkle keeps the install window visible while the callback is deferred.
        // Explain the wait in a separate nonmodal window without blocking the ticker.
        if notice == nil {
            let alert = NSAlert(); alert.messageText = "업데이트 설치를 기다리고 있어요"
            alert.informativeText = reason; alert.addButton(withTitle: "확인")
            alert.buttons.first?.target = self
            alert.buttons.first?.action = #selector(dismissNotice)
            notice = alert; NSApp.activate(ignoringOtherApps: true); alert.window.level = .floating
            alert.window.center(); alert.window.makeKeyAndOrderFront(nil)
        }
        return true
    }
    @objc private func dismissNotice() { notice?.window.close(); notice = nil }
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) { gate.cancel(); dismissNotice(); waitingMessage = nil; store.setUpdateInstallationInProgress(false) }
}
