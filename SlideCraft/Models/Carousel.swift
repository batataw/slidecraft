//
//  Carousel.swift
//  SlideCraft
//

import Foundation
import SwiftData

enum TikTokPublishStatus {
    case none
    case draft
    case published
}

@Model
final class Carousel {
    var id: UUID
    var subject: String
    var setting: String?
    var createdAt: Date
    var updatedAt: Date

    // Image de référence générée montrant les personnages en discussion
    var referenceImagePath: String?

    // TikTok publishing
    var tiktokTitle: String?
    var tiktokDescription: String?
    var tiktokPostId: String?
    var tiktokPublishedAt: Date?

    @Relationship(deleteRule: .cascade)
    var slides: [Slide]

    @Relationship
    var characters: [Character]

    @Relationship
    var background: Background?

    var sortedSlides: [Slide] {
        slides.sorted { $0.index < $1.index }
    }

    var allTextsValidated: Bool {
        !slides.isEmpty && slides.allSatisfy { $0.isValidated }
    }

    var allImagesValidated: Bool {
        !slides.isEmpty && slides.allSatisfy { $0.isImageValidated }
    }

    var isComplete: Bool {
        allTextsValidated && allImagesValidated
    }

    var tiktokPublishStatus: TikTokPublishStatus {
        if tiktokPostId != nil {
            return .published
        } else if tiktokTitle != nil || tiktokDescription != nil {
            return .draft
        }
        return .none
    }

    init(id: UUID = UUID(), subject: String) {
        self.id = id
        self.subject = subject
        self.createdAt = Date()
        self.updatedAt = Date()
        self.slides = []
        self.characters = []
    }
}
