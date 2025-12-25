//
//  CharactersView.swift
//  SlideCraft
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CharactersView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Character.createdAt, order: .reverse) private var characters: [Character]

    @State private var showingCreateSheet = false
    @State private var characterToEdit: Character?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Content
            ScrollView {
                VStack(spacing: SCSpacing.xl) {
                    // Info card
                    infoCard

                    // Characters grid
                    if characters.isEmpty {
                        emptyState
                    } else {
                        charactersGrid
                    }
                }
                .padding(SCSpacing.lg)
            }
        }
        .background(Color.scBackground)
        .sheet(isPresented: $showingCreateSheet) {
            CharacterEditorSheet(character: nil) { newCharacter in
                modelContext.insert(newCharacter)
            }
        }
        .sheet(item: $characterToEdit) { character in
            CharacterEditorSheet(character: character) { _ in }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                appState.navigateToHome()
            } label: {
                HStack(spacing: SCSpacing.sm) {
                    Image(systemName: "chevron.left")
                    Text("Accueil")
                }
            }
            .buttonStyle(SCGhostButtonStyle())

            Spacer()

            Text("Mes Personnages")
                .font(SCTypography.headline)
                .foregroundColor(.scText)

            Spacer()

            Button {
                showingCreateSheet = true
            } label: {
                HStack(spacing: SCSpacing.sm) {
                    Image(systemName: "plus")
                    Text("Nouveau")
                }
            }
            .buttonStyle(SCPrimaryButtonStyle())
        }
        .padding(.horizontal, SCSpacing.lg)
        .padding(.vertical, SCSpacing.md)
        .background(Color.scBackgroundSecondary)
        .overlay(alignment: .bottom) {
            SCDivider()
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        HStack(spacing: SCSpacing.lg) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.scSecondary)

            VStack(alignment: .leading, spacing: SCSpacing.xs) {
                Text("Cr\u{00e9}ez vos personnages")
                    .font(SCTypography.headline)
                    .foregroundColor(.scText)

                Text("Donnez un nom et un rôle à chaque personnage. L'IA générera automatiquement leur apparence visuelle lors de la création du carrousel.")
                    .font(SCTypography.body)
                    .foregroundColor(.scTextSecondary)
            }

            Spacer()
        }
        .padding(SCSpacing.lg)
        .background(Color.scSecondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: SCRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: SCRadius.lg)
                .stroke(Color.scSecondary.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        SCEmptyState(
            icon: "person.crop.circle.badge.plus",
            title: "Aucun personnage",
            message: "Cr\u{00e9}ez vos personnages pour commencer",
            action: { showingCreateSheet = true },
            actionLabel: "Cr\u{00e9}er un personnage"
        )
        .padding(.top, SCSpacing.xxl)
    }

    // MARK: - Characters Grid

    private var charactersGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: SCSpacing.lg) {
            ForEach(characters) { character in
                CharacterCard(character: character) {
                    characterToEdit = character
                } onDelete: {
                    deleteCharacter(character)
                }
            }
        }
    }

    // MARK: - Actions

    private func deleteCharacter(_ character: Character) {
        // Delete image file if exists
        if let imagePath = character.imagePath {
            try? FileManager.default.removeItem(atPath: imagePath)
        }
        modelContext.delete(character)
    }
}

// MARK: - Character Card

private struct CharacterCard: View {
    let character: Character
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Image
            ZStack {
                if let imagePath = character.imagePath,
                   let image = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.scSurface)
                        .frame(height: 180)
                        .overlay(
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.scTextTertiary)
                        )
                }

                // Role badge
                VStack {
                    HStack {
                        Spacer()
                        SCBadge(text: character.role.displayName, color: roleColor)
                            .padding(SCSpacing.sm)
                    }
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))

            // Info
            VStack(alignment: .leading, spacing: SCSpacing.sm) {
                Text(character.name)
                    .font(SCTypography.headline)
                    .foregroundColor(.scText)

                HStack(spacing: SCSpacing.xs) {
                    Image(systemName: character.role.icon)
                        .font(.system(size: 12))
                    Text(character.role.description)
                        .font(SCTypography.caption)
                }
                .foregroundColor(.scTextTertiary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SCSpacing.md)
        }
        .background(Color.scCard)
        .clipShape(RoundedRectangle(cornerRadius: SCRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: SCRadius.lg)
                .stroke(isHovered ? Color.scPrimary.opacity(0.5) : Color.scBorder, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Modifier", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    private var roleColor: Color {
        switch character.role {
        case .candide: return .scSecondary
        case .guide: return .scPrimary
        case .joker: return .scWarning
        }
    }
}

// MARK: - Character Editor Sheet

struct CharacterEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let character: Character?
    let onSave: (Character) -> Void

    @State private var name: String = ""
    @State private var selectedRole: CharacterRole = .candide
    @State private var selectedImage: NSImage?
    @State private var existingImagePath: String?
    @State private var isDragging = false

    private var isEditing: Bool { character != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Annuler") {
                    dismiss()
                }
                .buttonStyle(SCGhostButtonStyle())

                Spacer()

                Text(isEditing ? "Modifier le personnage" : "Nouveau personnage")
                    .font(SCTypography.headline)
                    .foregroundColor(.scText)

                Spacer()

                Button("Enregistrer") {
                    saveCharacter()
                }
                .buttonStyle(SCPrimaryButtonStyle())
                .disabled(!canSave)
            }
            .padding(SCSpacing.lg)
            .background(Color.scBackgroundSecondary)

            SCDivider()

            // Content
            ScrollView {
                VStack(spacing: SCSpacing.xl) {
                    // Image picker
                    imagePickerSection

                    // Name field
                    VStack(alignment: .leading, spacing: SCSpacing.sm) {
                        Text("Pr\u{00e9}nom")
                            .font(SCTypography.caption)
                            .foregroundColor(.scTextTertiary)

                        TextField("Ex: Marie, Tom, Alex...", text: $name)
                            .textFieldStyle(SCTextFieldStyle())
                    }

                    // Role picker
                    VStack(alignment: .leading, spacing: SCSpacing.sm) {
                        Text("R\u{00f4}le")
                            .font(SCTypography.caption)
                            .foregroundColor(.scTextTertiary)

                        VStack(spacing: SCSpacing.sm) {
                            ForEach(CharacterRole.allCases, id: \.self) { role in
                                RoleOptionButton(
                                    role: role,
                                    isSelected: selectedRole == role
                                ) {
                                    selectedRole = role
                                }
                            }
                        }
                    }
                }
                .padding(SCSpacing.xl)
            }
        }
        .frame(width: 500, height: 600)
        .background(Color.scBackground)
        .onAppear {
            if let character = character {
                name = character.name
                selectedRole = character.role
                existingImagePath = character.imagePath
            }
        }
    }

    // MARK: - Image Picker Section

    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Text("Image du personnage (optionnel)")
                .font(SCTypography.caption)
                .foregroundColor(.scTextTertiary)

            ZStack {
                RoundedRectangle(cornerRadius: SCRadius.lg)
                    .fill(isDragging ? Color.scPrimary.opacity(0.1) : Color.scSurface)
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: SCRadius.lg)
                            .stroke(
                                isDragging ? Color.scPrimary : Color.scBorder,
                                style: StrokeStyle(lineWidth: 2, dash: isDragging ? [] : [8])
                            )
                    )

                if let image = selectedImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
                } else if let path = existingImagePath, let image = NSImage(contentsOfFile: path) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
                } else {
                    VStack(spacing: SCSpacing.md) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 32))
                            .foregroundColor(.scTextTertiary)

                        Text("L'apparence sera générée par l'IA")
                            .font(SCTypography.body)
                            .foregroundColor(.scTextSecondary)

                        Text("Ou glissez une image pour personnaliser")
                            .font(SCTypography.caption)
                            .foregroundColor(.scTextTertiary)
                    }
                }
            }
            .onTapGesture {
                selectImage()
            }
            .onDrop(of: [.image, .fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers: providers)
            }
        }
    }

    // MARK: - Actions

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            if let image = NSImage(contentsOf: url) {
                selectedImage = image
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadObject(ofClass: NSImage.self) { image, _ in
                DispatchQueue.main.async {
                    if let nsImage = image as? NSImage {
                        selectedImage = nsImage
                    }
                }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                DispatchQueue.main.async {
                    if let data = data as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil),
                       let image = NSImage(contentsOf: url) {
                        selectedImage = image
                    }
                }
            }
            return true
        }

        return false
    }

    private func saveCharacter() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = character {
            // Update existing
            existing.name = trimmedName
            existing.role = selectedRole

            if let newImage = selectedImage {
                // Save new image
                let imagePath = saveImage(newImage, for: existing.id)
                existing.imagePath = imagePath
            }
        } else {
            // Create new
            let newCharacter = Character(name: trimmedName, role: selectedRole)

            if let image = selectedImage {
                let imagePath = saveImage(image, for: newCharacter.id)
                newCharacter.imagePath = imagePath
            }

            onSave(newCharacter)
        }

        dismiss()
    }

    private func saveImage(_ image: NSImage, for id: UUID) -> String? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let charactersDir = appSupport.appendingPathComponent("SlideCraft/Characters")

        try? FileManager.default.createDirectory(at: charactersDir, withIntermediateDirectories: true)

        let fileName = "\(id.uuidString).png"
        let fileURL = charactersDir.appendingPathComponent(fileName)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        do {
            try pngData.write(to: fileURL)
            return fileURL.path
        } catch {
            return nil
        }
    }
}

// MARK: - Role Option Button

private struct RoleOptionButton: View {
    let role: CharacterRole
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: SCSpacing.md) {
                Image(systemName: role.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? roleColor : .scTextSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(role.displayName)
                        .font(SCTypography.headline)
                        .foregroundColor(isSelected ? .scText : .scTextSecondary)

                    Text(role.description)
                        .font(SCTypography.caption)
                        .foregroundColor(.scTextTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(roleColor)
                }
            }
            .padding(SCSpacing.md)
            .background(isSelected ? roleColor.opacity(0.1) : (isHovered ? Color.scSurfaceHover : Color.scSurface))
            .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: SCRadius.md)
                    .stroke(isSelected ? roleColor.opacity(0.5) : Color.scBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var roleColor: Color {
        switch role {
        case .candide: return .scSecondary
        case .guide: return .scPrimary
        case .joker: return .scWarning
        }
    }
}

#Preview {
    CharactersView()
        .environment(AppState())
        .modelContainer(for: [Character.self, Carousel.self, Slide.self])
}
