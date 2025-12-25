//
//  Background.swift
//  SlideCraft
//

import Foundation
import SwiftData

@Model
final class Background {
    var id: UUID
    var name: String
    var imagePath: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        imagePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.imagePath = imagePath
        self.createdAt = Date()
    }
}
