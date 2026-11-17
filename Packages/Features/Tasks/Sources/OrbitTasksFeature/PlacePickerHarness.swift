import Foundation
import SwiftUI
import OrbitKit

/// CI smoke test for the place picker. Launched only with the
/// `-OrbitPlacePickerHarness` argument in Debug builds: presents the real
/// picker in a sheet (as Tasks does), moves its camera on a timer, and
/// prints a heartbeat. `Scripts/ci/place-picker-smoke.sh` runs it in the
/// simulator and fails the build if the main thread stalls or UIKit
/// reports a layout loop: the class of bug that froze the picker on device
/// and that compile-only CI couldn't see.
public struct PlacePickerHarness: View {
    public static let launchArgument = "-OrbitPlacePickerHarness"

    /// True only in Debug builds launched with the harness argument.
    public static var isRequested: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(launchArgument)
        #else
        false
        #endif
    }

    @State private var isPresented = false
    @State private var finder = PlaceFinder()

    public init() {}

    public var body: some View {
        Color.clear
            .sheet(isPresented: $isPresented) {
                PlacePickerSheet(
                    placeName: "Mom\u{2019}s",
                    finder: finder,
                    onPick: { _, _ in print("ORBIT_HARNESS_PICKED") },
                    onCancel: { isPresented = false },
                    harnessMovesCamera: true
                )
                .presentationDetents([.large])
            }
            .task {
                MainThreadWatchdog.shared.start()
                isPresented = true
                print("ORBIT_HARNESS_PRESENTED")
            }
    }
}

/// Pings the main thread from a background thread. A ping unanswered for
/// longer than `hangThreshold` is reported as a hang; otherwise a heartbeat
/// is printed every `heartbeatInterval`.
final class MainThreadWatchdog: @unchecked Sendable {
    static let shared = MainThreadWatchdog()

    private static let pingInterval: TimeInterval = 0.25
    private static let hangThreshold: TimeInterval = 2
    private static let heartbeatInterval: TimeInterval = 2

    private let lock = NSLock()
    private var lastPong = Date()
    private var started = false

    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !started else { return }
        started = true
        lastPong = Date()
        Thread.detachNewThread { [self] in run() }
    }

    private func run() {
        var lastHeartbeat = Date()
        while true {
            Thread.sleep(forTimeInterval: Self.pingInterval)
            DispatchQueue.main.async { [self] in
                lock.lock()
                lastPong = Date()
                lock.unlock()
            }
            lock.lock()
            let silence = Date().timeIntervalSince(lastPong)
            lock.unlock()
            if silence > Self.hangThreshold {
                print("ORBIT_HARNESS_HANG main thread unresponsive for \(String(format: "%.1f", silence))s")
            } else if Date().timeIntervalSince(lastHeartbeat) >= Self.heartbeatInterval {
                print("ORBIT_HARNESS_ALIVE")
                lastHeartbeat = Date()
            }
        }
    }
}
