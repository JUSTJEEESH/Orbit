import SwiftUI
import LockedCameraCapture
import AVFoundation
import UIKit

/// The capture surface presented over the Lock Screen. Intentionally
/// minimal: aim, tap, captured. No editing, no review — anything heavier
/// belongs inside the unlocked app.
///
/// Saved artifacts land in `session.sessionContentURL`, which the host app
/// drains via `LockedCameraCaptureManager.sessionContentUpdates`.
struct CameraCaptureView: View {
    let session: LockedCameraCaptureSession
    @State private var controller = CameraController()
    @State private var flash = false
    @State private var savedCount = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(controller: controller)
                .ignoresSafeArea()
                .opacity(controller.isRunning ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: controller.isRunning)

            if flash {
                Color.white.ignoresSafeArea()
                    .transition(.opacity)
            }

            VStack {
                topBar
                Spacer()
                shutterRow
            }
        }
        .task { await controller.start() }
        .onDisappear { controller.stop() }
        .statusBarHidden()
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                Text("Orbit")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            Spacer()
            if savedCount > 0 {
                Text("\(savedCount) saved")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
    }

    private var shutterRow: some View {
        HStack(spacing: 60) {
            Button { controller.toggleCameraPosition() } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Flip camera")

            Button { capture() } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 78, height: 78)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 62, height: 62)
                }
            }
            .accessibilityLabel("Capture photo")

            Color.clear.frame(width: 56, height: 56)
        }
        .padding(.bottom, 44)
    }

    private func capture() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            guard let data = await controller.capturePhoto() else { return }
            await save(data)
            await MainActor.run {
                savedCount += 1
                withAnimation(.linear(duration: 0.04)) { flash = true }
            }
            try? await Task.sleep(for: .milliseconds(80))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) { flash = false }
            }
        }
    }

    /// Writes the JPEG plus a sibling JSON envelope so the host can ingest
    /// the file deterministically — no guessing at file types or dates.
    private func save(_ data: Data) async {
        let id = UUID()
        let dir = session.sessionContentURL
        let imageURL = dir.appendingPathComponent("\(id.uuidString).jpg")
        let envelopeURL = dir.appendingPathComponent("\(id.uuidString).json")

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: imageURL, options: .atomic)
            let envelope: [String: Any] = [
                "id": id.uuidString,
                "kind": "photo",
                "source": "lockCamera",
                "imageFilename": imageURL.lastPathComponent,
                "createdAt": ISO8601DateFormatter().string(from: Date())
            ]
            let json = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
            try json.write(to: envelopeURL, options: .atomic)
        } catch {
            // Lock-Screen flow can't surface errors; the user will only see
            // missing rows on re-launch. Acceptable for v1.
        }
    }
}
