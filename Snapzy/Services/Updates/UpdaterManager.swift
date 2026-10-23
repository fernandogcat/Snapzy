//
//  UpdaterManager.swift
//  Snapzy
//
//  Shared Sparkle updater manager — singleton, starts updater once, logs lifecycle via DiagnosticLogger
//

import Sparkle

/// Sparkle update channel. Stable is the default; beta opts into pre-release builds.
enum UpdateChannel: String, CaseIterable {
  case stable
  case beta
}

final class UpdaterManager: NSObject, SPUUpdaterDelegate {
  static let shared = UpdaterManager()

  /// Current channel from UserDefaults; missing or invalid value resolves to stable.
  static var channel: UpdateChannel {
    UpdateChannel(rawValue: UserDefaults.standard.string(forKey: PreferencesKeys.updateChannel) ?? "") ?? .stable
  }

  private(set) var controller: SPUStandardUpdaterController!

  var updater: SPUUpdater {
    controller.updater
  }

  /// Local builds pass SNAPZY_DISABLE_UPDATER so Sparkle never replaces them with the official release.
  #if SNAPZY_DISABLE_UPDATER
  static let isDisabled = true
  #else
  static let isDisabled = false
  #endif

  private override init() {
    super.init()
    controller = SPUStandardUpdaterController(
      startingUpdater: !Self.isDisabled,
      updaterDelegate: self,
      userDriverDelegate: nil
    )
    DiagnosticLogger.shared.log(.info, .update, Self.isDisabled ? "Updater disabled in this build" : "Updater initialized")
  }

  func checkForUpdates() {
    guard !Self.isDisabled else {
      DiagnosticLogger.shared.log(.info, .update, "Manual check for updates ignored: updater disabled in this build")
      return
    }
    DiagnosticLogger.shared.log(.info, .update, "Manual check for updates triggered")
    updater.checkForUpdates()
  }

  // MARK: - SPUUpdaterDelegate

  func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
    if Self.isDisabled {
      throw NSError(
        domain: "Snapzy.Updater",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Updates are disabled in this build"]
      )
    }
  }

  func allowedChannels(for updater: SPUUpdater) -> Set<String> {
    let channel = Self.channel
    DiagnosticLogger.shared.log(.info, .update, "Allowed channels: \(channel == .beta ? "[beta]" : "[] (stable)")")
    return channel == .beta ? ["beta"] : []
  }

  func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
    let count = appcast.items.count
    DiagnosticLogger.shared.log(.info, .update, "Appcast loaded: \(count) item(s)")
  }

  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    let version = item.displayVersionString
    let build = item.versionString
    DiagnosticLogger.shared.log(.info, .update, "Update available: v\(version) (\(build))")
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
    DiagnosticLogger.shared.log(.warning, .update, "No update found: \(error.localizedDescription) [code=\((error as NSError).code), domain=\((error as NSError).domain)]")
  }

  func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
    let version = item.displayVersionString
    DiagnosticLogger.shared.log(.info, .update, "Downloaded update: v\(version)")
  }

  func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
    let version = item.displayVersionString
    DiagnosticLogger.shared.log(.info, .update, "Installing update: v\(version)")
  }

  func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
    let nsError = error as NSError
    DiagnosticLogger.shared.log(
      .error, .update,
      "Update aborted: \(nsError.localizedDescription) [code=\(nsError.code), domain=\(nsError.domain), info=\(nsError.userInfo)]"
    )
  }

  func updater(_ updater: SPUUpdater, didCancelInstallUpdateOnQuit item: SUAppcastItem) {
    let version = item.displayVersionString
    DiagnosticLogger.shared.log(.warning, .update, "User cancelled install on quit: v\(version)")
  }
}
