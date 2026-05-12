import SwiftUI
import AVFoundation
import UIKit

/// Thin `AVCaptureSession` host. Lives on `@MainActor` because SwiftUI reads
/// `isRunning` for the preview-fade-in; the underlying `AVCaptureSession` is
/// documented as thread-safe so calling `startRunning()` directly from the
/// task continuation is fine even though Apple's sample code uses a session
/// queue.
@MainActor
@Observable
final class CameraController {
    let session = AVCaptureSession()
    private(set) var isRunning = false
    private var videoInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private var currentPosition: AVCaptureDevice.Position = .back
    private var photoDelegate: PhotoCaptureDelegate?

    func start() async {
        await ensureConfigured()
        // `startRunning()` blocks until the session is up — punt to a
        // detached task so the SwiftUI tree paints first.
        let session = session
        await Task.detached(priority: .userInitiated) {
            if !session.isRunning { session.startRunning() }
        }.value
        isRunning = session.isRunning
    }

    func stop() {
        let session = session
        Task.detached(priority: .utility) {
            if session.isRunning { session.stopRunning() }
        }
        isRunning = false
    }

    func toggleCameraPosition() {
        let target: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        currentPosition = target
        session.beginConfiguration()
        if let videoInput {
            session.removeInput(videoInput)
            self.videoInput = nil
        }
        if let input = makeInput(for: target), session.canAddInput(input) {
            session.addInput(input)
            videoInput = input
        }
        session.commitConfiguration()
    }

    func capturePhoto() async -> Data? {
        await withCheckedContinuation { continuation in
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            let delegate = PhotoCaptureDelegate { data in
                continuation.resume(returning: data)
            }
            photoDelegate = delegate
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func ensureConfigured() async {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let input = makeInput(for: currentPosition), session.canAddInput(input) {
            session.addInput(input)
            videoInput = input
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .balanced
        }
        session.commitConfiguration()
    }

    private func makeInput(for position: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return nil }
        return input
    }
}

/// One-shot photo delegate. Holds itself alive via `CameraController`'s
/// strong reference and fires its continuation exactly once.
final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Data?) -> Void
    private var fired = false

    init(completion: @escaping @Sendable (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard !fired else { return }
        fired = true
        completion(photo.fileDataRepresentation())
    }
}

/// `UIView` -> SwiftUI bridge for the live preview layer. Using a custom
/// `layerClass` override keeps the preview layer the same instance for the
/// view's lifetime, so we never have to swap session bindings on rotation.
struct CameraPreview: UIViewRepresentable {
    let controller: CameraController

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = controller.session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
