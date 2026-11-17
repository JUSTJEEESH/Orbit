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
        return ProcessInfo.processInfo.arguments.contains(launchArgument)
        #else
        false
        #endif
    }

    @State private var isPresented = false
    @State private var finder = PlaceFinder()

    public init() {}

    // The old SwiftUI `Map` picker (LegacyMapPickerRepro, now removed)
    // was run here too until the fix shipped: this test flagged it every
    // time (main thread stuck, ~97% CPU), proving it can see that hang.
    private var pickerUnderTest: some View {
        PlacePickerSheet(
            placeName: "Mom\u{2019}s",
            finder: finder,
            onPick: { _, _ in print("ORBIT_HARNESS_PICKED") },
            onCancel: { isPresented = false },
            harnessMovesCamera: true
        )
    }

    public var body: some View {
        Color.clear
            .sheet(isPresented: $isPresented) {
                pickerUnderTest
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
    /// The first MapKit load on a cold simulator can stall briefly; stalls
    /// this early are reported separately, not as hangs.
    private static let warmUp: TimeInterval = 8

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
        let startedAt = Date()
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
                let seconds = String(format: "%.1f", silence)
                if Date().timeIntervalSince(startedAt) < Self.warmUp {
                    print("ORBIT_HARNESS_WARMUP_STALL \(seconds)s")
                } else {
                    print("ORBIT_HARNESS_HANG main thread unresponsive for \(seconds)s")
                }
            } else if Date().timeIntervalSince(lastHeartbeat) >= Self.heartbeatInterval {
                print("ORBIT_HARNESS_ALIVE")
                lastHeartbeat = Date()
            }
        }
    }
}
