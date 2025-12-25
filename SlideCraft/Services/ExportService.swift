//
//  ExportService.swift
//  SlideCraft
//

import Foundation
import AppKit
import PDFKit
import Compression

final class ExportService: Sendable {
    static let slideSize = CGSize(width: 1920, height: 1080)

    enum ExportError: LocalizedError {
        case noSlides
        case imageLoadFailed(Int)
        case pdfCreationFailed
        case zipCreationFailed
        case directoryCreationFailed

        var errorDescription: String? {
            switch self {
            case .noSlides:
                return "Aucun slide à exporter"
            case .imageLoadFailed(let index):
                return "Impossible de charger l'image du slide \(index + 1)"
            case .pdfCreationFailed:
                return "Impossible de créer le PDF"
            case .zipCreationFailed:
                return "Impossible de créer le ZIP"
            case .directoryCreationFailed:
                return "Impossible de créer le dossier d'export"
            }
        }
    }

    // MARK: - Export as ZIP (containing PNG images)

    func exportAsZIP(carousel: Carousel, to zipURL: URL) async throws {
        let slides = carousel.sortedSlides

        guard !slides.isEmpty else {
            throw ExportError.noSlides
        }

        // Create temp directory for images with same name as ZIP file
        let folderName = zipURL.deletingPathExtension().lastPathComponent
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Copy images to temp directory
        for (index, slide) in slides.enumerated() {
            guard let imagePath = slide.imagePath,
                  let imageData = FileManager.default.contents(atPath: imagePath) else {
                throw ExportError.imageLoadFailed(index)
            }

            let fileName = String(format: "slide_%02d.png", index + 1)
            let fileURL = tempDir.appendingPathComponent(fileName)
            try imageData.write(to: fileURL)
        }

        // Create ZIP using NSFileCoordinator
        let coordinator = NSFileCoordinator()
        var error: NSError?

        // Remove existing file if present
        try? FileManager.default.removeItem(at: zipURL)

        coordinator.coordinate(readingItemAt: tempDir, options: .forUploading, error: &error) { zippedURL in
            do {
                try FileManager.default.copyItem(at: zippedURL, to: zipURL)
            } catch {
                // Error will be handled below
            }
        }

        if let error = error {
            throw error
        }

        // Verify the file was created
        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw ExportError.zipCreationFailed
        }
    }

    // MARK: - Export as PDF

    func exportAsPDF(carousel: Carousel, to fileURL: URL) async throws {
        let slides = carousel.sortedSlides

        guard !slides.isEmpty else {
            throw ExportError.noSlides
        }

        let pdfDocument = PDFDocument()

        for (index, slide) in slides.enumerated() {
            guard let imagePath = slide.imagePath,
                  let image = NSImage(contentsOfFile: imagePath) else {
                throw ExportError.imageLoadFailed(index)
            }

            guard let pdfPage = PDFPage(image: image) else {
                throw ExportError.pdfCreationFailed
            }

            pdfDocument.insert(pdfPage, at: index)
        }

        guard pdfDocument.write(to: fileURL) else {
            throw ExportError.pdfCreationFailed
        }
    }
}
