import Foundation
import Vision
import CoreImage

/// Vision-based text recognizer. Used to OCR screenshots and photos so
/// downstream search and AI classification have something to chew on even
/// when the user doesn't add a caption.
public actor OCRService {
    public init() {}

    public func extractText(from imageData: Data) async throws -> String? {
        guard let image = CIImage(data: imageData) else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try handler.perform([request])

        let lines = (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}
