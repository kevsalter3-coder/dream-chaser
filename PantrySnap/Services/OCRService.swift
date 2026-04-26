import Vision
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.pantrysnap", category: "OCRService")

struct ReceiptLineItem {
    var name: String
    var isSelected: Bool = true
}

struct ReceiptParseResult {
    var items: [ReceiptLineItem]
    var detectedDate: Date?
}

actor OCRService {
    // Regex patterns used to identify receipt line items.
    // A line is a candidate if it contains a price but is not a summary line.
    private let pricePattern      = try! NSRegularExpression(pattern: #"\$?\d+\.\d{2}"#)
    private let summaryKeywords   = ["subtotal", "sub total", "tax", "total", "amount", "change", "cash", "balance", "tip"]
    private let datePattern       = try! NSRegularExpression(pattern: #"(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})"#)

    func parseReceipt(from image: UIImage) async throws -> ReceiptParseResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        let observations = try await recognizeText(in: cgImage)
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }

        let detectedDate = extractDate(from: lines)
        let items = extractLineItems(from: lines)

        logger.info("OCR found \(items.count) candidate items from receipt (\(lines.count) lines total)")
        return ReceiptParseResult(items: items, detectedDate: detectedDate)
    }

    private func recognizeText(in cgImage: CGImage) async throws -> [VNRecognizedTextObservation] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let results = request.results as? [VNRecognizedTextObservation] ?? []
                continuation.resume(returning: results)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func extractLineItems(from lines: [String]) -> [ReceiptLineItem] {
        lines.compactMap { line in
            let lower = line.lowercased()

            // Skip summary lines
            guard !summaryKeywords.contains(where: { lower.contains($0) }) else { return nil }

            // Must contain a price pattern
            let range = NSRange(line.startIndex..., in: line)
            guard pricePattern.firstMatch(in: line, range: range) != nil else { return nil }

            // Strip trailing price and clean up item name
            let cleaned = pricePattern
                .stringByReplacingMatches(in: line, range: range, withTemplate: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "$,.-"))
                .capitalized

            guard cleaned.count >= 3 else { return nil }
            return ReceiptLineItem(name: cleaned)
        }
    }

    private func extractDate(from lines: [String]) -> Date? {
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = datePattern.firstMatch(in: line, range: range),
                  let swiftRange = Range(match.range, in: line)
            else { continue }

            let dateString = String(line[swiftRange])
            for format in ["MM/dd/yyyy", "MM/dd/yy", "MM-dd-yyyy", "dd/MM/yyyy"] {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) { return date }
            }
        }
        return nil
    }
}

enum OCRError: Error {
    case invalidImage
}
