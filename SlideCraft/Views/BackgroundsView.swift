//
//  BackgroundsView.swift
//  SlideCraft
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackgroundsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Background.createdAt, order: .reverse) private var backgrounds: [Background]

    @State private var showingCreateSheet = false
    @State private var backgroundToEdit: Background?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Content
            ScrollView {
                VStack(spacing: SCSpacing.xl) {
                    // Info card
                    infoCard

                    // Backgrounds grid
                    if backgrounds.isEmpty {
                        emptyState
                    } else {
                        backgroundsGrid
                    }
                }
                .padding(SCSpacing.lg)
            }
        }
        .background(Color.scBackground)
        .sheet(isPresented: $showingCreateSheet) {
            BackgroundEditorSheet(background: nil) { newBackground in
                modelContext.insert(newBackground)
            }
        }
        .sheet(item: $backgroundToEdit) { background in
            BackgroundEditorSheet(background: background) { _ in }
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

            Text("Mes Backgrounds")
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
            Image(systemName: "photo.artframe")
                .font(.system(size: 24))
                .foregroundColor(.scSecondary)

            VStack(alignment: .leading, spacing: SCSpacing.xs) {
                Text("Vos images de fond")
                    .font(SCTypography.headline)
                    .foregroundColor(.scText)

                Text("Uploadez des images de fond pour vos carrousels. Le background sera utilisé comme décor pour toutes les slides.")
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
            icon: "photo.on.rectangle.angled",
            title: "Aucun background",
            message: "Ajoutez votre premier background",
            action: { showingCreateSheet = true },
            actionLabel: "Ajouter un background"
        )
        .padding(.top, SCSpacing.xxl)
    }

    // MARK: - Backgrounds Grid

    private var backgroundsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))], spacing: SCSpacing.md) {
            ForEach(backgrounds) { background in
                BackgroundCard(background: background) {
                    backgroundToEdit = background
                } onDelete: {
                    deleteBackground(background)
                }
            }
        }
    }

    // MARK: - Actions

    private func deleteBackground(_ background: Background) {
        // Delete image file
        if let imagePath = background.imagePath {
            try? FileManager.default.removeItem(atPath: imagePath)
        }
        modelContext.delete(background)
    }
}

// MARK: - Background Card

private struct BackgroundCard: View {
    let background: Background
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Image preview (landscape aspect ratio)
            ZStack {
                if let imagePath = background.imagePath,
                   let image = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.scSurface)
                        .frame(height: 140)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(.scTextTertiary)
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: SCRadius.md, style: .continuous))

            // Info
            HStack {
                Text(background.name)
                    .font(SCTypography.callout)
                    .foregroundColor(.scText)
                    .lineLimit(1)

                Spacer()

                // Actions
                HStack(spacing: SCSpacing.xs) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.scTextSecondary)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.scError)
                }
                .opacity(isHovered ? 1 : 0)
            }
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
    }
}

// MARK: - Background Editor Sheet

private struct BackgroundEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let background: Background?
    let onSave: (Background) -> Void

    @State private var name: String = ""
    @State private var selectedImageData: Data?
    @State private var selectedImagePath: String?
    @State private var isDragging = false

    private var isEditing: Bool { background != nil }
    private var canSave: Bool { !name.isEmpty && (selectedImagePath != nil || background?.imagePath != nil) }

    init(background: Background?, onSave: @escaping (Background) -> Void) {
        self.background = background
        self.onSave = onSave
        if let background = background {
            _name = State(initialValue: background.name)
            _selectedImagePath = State(initialValue: background.imagePath)
        }
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

                Text(isEditing ? "Modifier le background" : "Nouveau background")
                    .font(SCTypography.headline)
                    .foregroundColor(.scText)

                Spacer()

                Button("Enregistrer") {
                    save()
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
                    // Image drop zone
                    imageDropZone

                    // Name field
                    VStack(alignment: .leading, spacing: SCSpacing.sm) {
                        Text("Nom du background")
                            .font(SCTypography.caption)
                            .foregroundColor(.scTextTertiary)

                        TextField("Ex: Forêt enchantée, Bureau moderne...", text: $name)
                            .textFieldStyle(.plain)
                            .font(SCTypography.body)
                            .padding(SCSpacing.md)
                            .background(Color.scSurface)
                            .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: SCRadius.md)
                                    .stroke(Color.scBorder, lineWidth: 1)
                            )
                    }
                }
                .padding(SCSpacing.xl)
            }
        }
        .frame(width: 500, height: 500)
        .background(Color.scBackground)
    }

    // MARK: - Image Drop Zone

    private var imageDropZone: some View {
        VStack(spacing: SCSpacing.md) {
            if let imagePath = selectedImagePath,
               let image = NSImage(contentsOfFile: imagePath) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))

                Button("Changer l'image") {
                    selectImage()
                }
                .buttonStyle(SCSecondaryButtonStyle())
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: SCRadius.lg)
                        .fill(isDragging ? Color.scPrimary.opacity(0.1) : Color.scSurface)
                        .frame(height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: SCRadius.lg)
                                .stroke(
                                    isDragging ? Color.scPrimary : Color.scBorder,
                                    style: StrokeStyle(lineWidth: 2, dash: [8])
                                )
                        )

                    VStack(spacing: SCSpacing.md) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(isDragging ? .scPrimary : .scTextTertiary)

                        Text("Glissez une image ici")
                            .font(SCTypography.body)
                            .foregroundColor(.scTextSecondary)

                        Text("ou")
                            .font(SCTypography.caption)
                            .foregroundColor(.scTextTertiary)

                        Button("Parcourir") {
                            selectImage()
                        }
                        .buttonStyle(SCSecondaryButtonStyle())
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                    handleDrop(providers: providers)
                }
            }
        }
    }

    // MARK: - Actions

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            loadImage(from: url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

            DispatchQueue.main.async {
                loadImage(from: url)
            }
        }
        return true
    }

    private func loadImage(from url: URL) {
        guard let imageData = try? Data(contentsOf: url) else { return }

        // Save to app support
        let fileName = "\(UUID().uuidString).\(url.pathExtension)"
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let backgroundsDir = appSupport.appendingPathComponent("SlideCraft/Backgrounds")
        try? FileManager.default.createDirectory(at: backgroundsDir, withIntermediateDirectories: true)

        let destinationURL = backgroundsDir.appendingPathComponent(fileName)
        try? imageData.write(to: destinationURL)

        selectedImagePath = destinationURL.path
        selectedImageData = imageData

        // Auto-fill name from filename if empty
        if name.isEmpty {
            name = url.deletingPathExtension().lastPathComponent
        }
    }

    private func save() {
        if let existingBackground = background {
            existingBackground.name = name
            if let newPath = selectedImagePath, newPath != existingBackground.imagePath {
                // Delete old image
                if let oldPath = existingBackground.imagePath {
                    try? FileManager.default.removeItem(atPath: oldPath)
                }
                existingBackground.imagePath = newPath
            }
        } else {
            let newBackground = Background(name: name, imagePath: selectedImagePath)
            onSave(newBackground)
        }
        dismiss()
    }
}

#Preview {
    BackgroundsView()
        .environment(AppState())
        .modelContainer(for: [Background.self])
}
