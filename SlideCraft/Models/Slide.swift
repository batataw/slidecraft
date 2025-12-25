//
//  Slide.swift
//  SlideCraft
//

import Foundation
import SwiftData

@Model
final class Slide {
    var id: UUID
    var index: Int
    var text: String
    var isValidated: Bool
    var isImageValidated: Bool
    var visualPrompt: String?
    var imagePath: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        index: Int,
        text: String,
        isValidated: Bool = false,
        isImageValidated: Bool = false,
        visualPrompt: String? = nil,
        imagePath: String? = nil
    ) {
        self.id = id
        self.index = index
        self.text = text
        self.isValidated = isValidated
        self.isImageValidated = isImageValidated
        self.visualPrompt = visualPrompt
        self.imagePath = imagePath
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
