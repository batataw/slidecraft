//
//  Character.swift
//  SlideCraft
//

import Foundation
import SwiftData

enum CharacterRole: String, CaseIterable, Codable {
    case candide = "candide"
    case guide = "guide"
    case joker = "joker"

    var displayName: String {
        switch self {
        case .candide: return "Le Candide"
        case .guide: return "Le Guide"
        case .joker: return "Le Joker"
        }
    }

    var description: String {
        switch self {
        case .candide: return "Pose les questions naïves, représente l'audience"
        case .guide: return "Explique, enseigne, apporte les réponses"
        case .joker: return "Apporte l'humour, les analogies décalées"
        }
    }

    var icon: String {
        switch self {
        case .candide: return "questionmark.circle"
        case .guide: return "lightbulb"
        case .joker: return "theatermasks"
        }
    }
}

@Model
final class Character {
    var id: UUID
    var name: String
    var roleRawValue: String
    var imagePath: String?
    var createdAt: Date

    var role: CharacterRole {
        get { CharacterRole(rawValue: roleRawValue) ?? .candide }
        set { roleRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        role: CharacterRole,
        imagePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.roleRawValue = role.rawValue
        self.imagePath = imagePath
        self.createdAt = Date()
    }
}
