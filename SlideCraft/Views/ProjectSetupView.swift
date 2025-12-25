//
//  ProjectSetupView.swift
//  SlideCraft
//
//  Consolidated view for project setup: characters + background + subject

import SwiftUI
import SwiftData

struct ProjectSetupView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Character.createdAt, order: .reverse) private var characters: [Character]
    @Query(sort: \Background.createdAt, order: .reverse) private var backgrounds: [Background]

    @State private var selectedCharacterIDs: Set<UUID> = []
    @State private var selectedBackgroundID: UUID?
    @State private var subject: String = ""

    private var selectedCharacters: [Character] {
        characters.filter { selectedCharacterIDs.contains($0.id) }
    }

    private var selectedBackground: Background? {
        backgrounds.first { $0.id == selectedBackgroundID }
    }

    // MARK: - Validation

    private var hasCandide: Bool {
        selectedCharacters.contains { $0.role == .candide }
    }

    private var hasGuide: Bool {
        selectedCharacters.contains { $0.role == .guide }
    }

    private var hasJoker: Bool {
        selectedCharacters.contains { $0.role == .joker }
    }

    private var charactersValid: Bool {
        hasCandide && hasGuide && hasJoker
    }

    private var backgroundValid: Bool {
        selectedBackgroundID != nil
    }

    private var subjectValid: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canGenerate: Bool {
        charactersValid && backgroundValid && subjectValid &&
        appState.isConfigured && !appState.carouselViewModel.isGenerating
    }

    private var missingItems: [String] {
        var missing: [String] = []
        if !hasCandide { missing.append("Candide") }
        if !hasGuide { missing.append("Guide") }
        if !hasJoker { missing.append("Joker") }
        if !backgroundValid { missing.append("Fond") }
        if !subjectValid { missing.append("Sujet") }
        return missing
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Content
            HSplitView {
                // Left: Setup form
                setupPanel
                    .frame(minWidth: 500)

                // Right: Summary
                summaryPanel
                    .frame(minWidth: 280, maxWidth: 350)
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .background(Color.scBackground)
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

            Text("Nouveau Carrousel")
                .font(SCTypography.headline)
                .foregroundColor(.scText)

            Spacer()

            // Generate button
            Button {
                Task {
                    await createCarousel()
                }
            } label: {
                HStack(spacing: SCSpacing.sm) {
                    Image(systemName: "sparkles")
                    Text("Générer le scénario")
                }
            }
            .buttonStyle(SCPrimaryButtonStyle())
            .disabled(!canGenerate)
        }
        .padding(.horizontal, SCSpacing.lg)
        .padding(.vertical, SCSpacing.md)
        .background(Color.scBackgroundSecondary)
        .overlay(alignment: .bottom) {
            SCDivider()
        }
    }

    // MARK: - Setup Panel

    private var setupPanel: some View {
        ScrollView {
            VStack(spacing: SCSpacing.xl) {
                // Subject section
                subjectSection

                SCDivider()

                // Characters section
                charactersSection

                SCDivider()

                // Background section
                backgroundSection

                Spacer(minLength: SCSpacing.xl)
            }
            .padding(SCSpacing.lg)
        }
    }

    // MARK: - Subject Section

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.md) {
            HStack {
                SCSectionHeader(
                    title: "Sujet",
                    subtitle: "Décrivez le sujet que vous voulez expliquer"
                )

                Spacer()

                if subjectValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.scSuccess)
                }
            }

            TextEditor(text: $subject)
                .font(SCTypography.body)
                .foregroundColor(.scText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(SCSpacing.md)
                .background(Color.scSurface)
                .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: SCRadius.md)
                        .stroke(subjectValid ? Color.scSuccess.opacity(0.5) : Color.scBorder, lineWidth: 1)
                )

            // Examples
            HStack(spacing: SCSpacing.sm) {
                Text("Exemples :")
                    .font(SCTypography.caption)
                    .foregroundColor(.scTextTertiary)

                ForEach(exampleSubjects.prefix(3), id: \.self) { example in
                    Button {
                        subject = example
                    } label: {
                        Text(example)
                            .font(SCTypography.caption)
                            .foregroundColor(.scTextSecondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, SCSpacing.sm)
                    .padding(.vertical, 4)
                    .background(Color.scSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.scBorder, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Characters Section

    private var charactersSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.md) {
            HStack {
                SCSectionHeader(
                    title: "Personnages",
                    subtitle: "Sélectionnez un Candide, un Guide et un Joker"
                )

                Spacer()

                if charactersValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.scSuccess)
                } else {
                    rolesStatus
                }

                Button {
                    appState.navigateToCharacters()
                } label: {
                    HStack(spacing: SCSpacing.xs) {
                        Image(systemName: "plus")
                        Text("Gérer")
                    }
                    .font(SCTypography.caption)
                }
                .buttonStyle(SCGhostButtonStyle())
            }

            if characters.isEmpty {
                SCEmptyState(
                    icon: "person.crop.circle.badge.plus",
                    title: "Aucun personnage",
                    message: "Créez d'abord vos personnages",
                    action: { appState.navigateToCharacters() },
                    actionLabel: "Créer des personnages"
                )
                .frame(height: 150)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: SCSpacing.sm) {
                    ForEach(characters) { character in
                        SelectableCharacterCard(
                            character: character,
                            isSelected: selectedCharacterIDs.contains(character.id)
                        ) {
                            toggleCharacter(character)
                        }
                    }
                }
            }
        }
    }

    private var rolesStatus: some View {
        HStack(spacing: SCSpacing.xs) {
            RoleIndicator(name: "C", fulfilled: hasCandide)
            RoleIndicator(name: "G", fulfilled: hasGuide)
            RoleIndicator(name: "J", fulfilled: hasJoker)
        }
    }

    // MARK: - Background Section

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.md) {
            HStack {
                SCSectionHeader(
                    title: "Décor",
                    subtitle: "Choisissez le fond pour vos images"
                )

                Spacer()

                if backgroundValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.scSuccess)
                }

                Button {
                    appState.navigateToBackgrounds()
                } label: {
                    HStack(spacing: SCSpacing.xs) {
                        Image(systemName: "plus")
                        Text("Gérer")
                    }
                    .font(SCTypography.caption)
                }
                .buttonStyle(SCGhostButtonStyle())
            }

            if backgrounds.isEmpty {
                SCEmptyState(
                    icon: "photo.on.rectangle.angled",
                    title: "Aucun décor",
                    message: "Créez d'abord vos backgrounds",
                    action: { appState.navigateToBackgrounds() },
                    actionLabel: "Créer des backgrounds"
                )
                .frame(height: 150)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: SCSpacing.sm) {
                    ForEach(backgrounds) { background in
                        SelectableBackgroundCard(
                            background: background,
                            isSelected: selectedBackgroundID == background.id
                        ) {
                            selectedBackgroundID = background.id
                        }
                    }
                }
            }
        }
    }

    // MARK: - Summary Panel

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Résumé")
                    .font(SCTypography.headline)
                    .foregroundColor(.scText)

                Spacer()
            }
            .padding(SCSpacing.md)
            .background(Color.scSurface)

            SCDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: SCSpacing.lg) {
                    // Subject summary
                    SummaryItem(
                        icon: "text.quote",
                        title: "Sujet",
                        content: subjectValid ? subject : "Non défini",
                        isValid: subjectValid
                    )

                    // Characters summary
                    VStack(alignment: .leading, spacing: SCSpacing.sm) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(charactersValid ? .scSuccess : .scTextTertiary)
                            Text("Personnages")
                                .font(SCTypography.callout)
                                .foregroundColor(.scText)
                        }

                        if selectedCharacters.isEmpty {
                            Text("Aucun sélectionné")
                                .font(SCTypography.caption)
                                .foregroundColor(.scTextTertiary)
                        } else {
                            ForEach(selectedCharacters) { character in
                                HStack(spacing: SCSpacing.sm) {
                                    if let imagePath = character.imagePath,
                                       let image = NSImage(contentsOfFile: imagePath) {
                                        Image(nsImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 28, height: 28)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color.scSurface)
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Text(character.name.prefix(1).uppercased())
                                                    .font(SCTypography.caption2)
                                                    .foregroundColor(.scTextSecondary)
                                            )
                                    }

                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(character.name)
                                            .font(SCTypography.caption)
                                            .foregroundColor(.scText)
                                        Text(character.role.displayName)
                                            .font(SCTypography.caption2)
                                            .foregroundColor(.scTextTertiary)
                                    }

                                    Spacer()

                                    Button {
                                        selectedCharacterIDs.remove(character.id)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9))
                                            .foregroundColor(.scTextTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(SCSpacing.md)
                    .background(Color.scCard)
                    .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))

                    // Background summary
                    VStack(alignment: .leading, spacing: SCSpacing.sm) {
                        HStack {
                            Image(systemName: "photo.artframe")
                                .foregroundColor(backgroundValid ? .scSuccess : .scTextTertiary)
                            Text("Décor")
                                .font(SCTypography.callout)
                                .foregroundColor(.scText)
                        }

                        if let background = selectedBackground {
                            HStack(spacing: SCSpacing.sm) {
                                if let imagePath = background.imagePath,
                                   let image = NSImage(contentsOfFile: imagePath) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: SCRadius.sm))
                                }

                                Text(background.name)
                                    .font(SCTypography.caption)
                                    .foregroundColor(.scText)

                                Spacer()

                                Button {
                                    selectedBackgroundID = nil
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9))
                                        .foregroundColor(.scTextTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Text("Non sélectionné")
                                .font(SCTypography.caption)
                                .foregroundColor(.scTextTertiary)
                        }
                    }
                    .padding(SCSpacing.md)
                    .background(Color.scCard)
                    .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))

                    Spacer()
                }
                .padding(SCSpacing.md)
            }

            // Bottom status
            VStack(spacing: SCSpacing.sm) {
                if !canGenerate {
                    if !appState.isConfigured {
                        HStack(spacing: SCSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.scWarning)
                            Text("Clé API requise")
                                .font(SCTypography.caption)
                                .foregroundColor(.scWarning)

                            Spacer()

                            Button("Configurer") {
                                appState.openSettings()
                            }
                            .buttonStyle(SCGhostButtonStyle())
                        }
                    } else if !missingItems.isEmpty {
                        HStack(spacing: SCSpacing.xs) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.scTextTertiary)
                            Text("Manque: \(missingItems.joined(separator: ", "))")
                                .font(SCTypography.caption)
                                .foregroundColor(.scTextTertiary)
                        }
                    }
                }

                if appState.carouselViewModel.isGenerating {
                    SCProgressIndicator(message: appState.carouselViewModel.generationProgress)
                }

                if let error = appState.carouselViewModel.errorMessage {
                    HStack(spacing: SCSpacing.sm) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.scError)
                        Text(error)
                            .font(SCTypography.caption)
                            .foregroundColor(.scError)
                            .lineLimit(2)

                        Spacer()

                        // Retry button if carousel exists but reference image failed
                        if let carousel = appState.carouselViewModel.currentCarousel,
                           carousel.referenceImagePath == nil {
                            Button {
                                Task {
                                    await retryReferenceImage()
                                }
                            } label: {
                                HStack(spacing: SCSpacing.xs) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Réessayer")
                                }
                                .font(SCTypography.caption)
                            }
                            .buttonStyle(SCSecondaryButtonStyle())
                            .disabled(appState.carouselViewModel.isGenerating)
                        }
                    }
                }
            }
            .padding(SCSpacing.md)
            .background(Color.scSurface)
        }
        .background(Color.scBackgroundSecondary)
    }

    // MARK: - Actions

    private func toggleCharacter(_ character: Character) {
        if selectedCharacterIDs.contains(character.id) {
            selectedCharacterIDs.remove(character.id)
        } else {
            selectedCharacterIDs.insert(character.id)
        }
    }

    private func createCarousel() async {
        appState.carouselViewModel.selectedCharacters = selectedCharacters
        if let background = selectedBackground {
            appState.carouselViewModel.selectedBackground = background
        }

        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        await appState.carouselViewModel.createCarousel(subject: trimmedSubject, context: modelContext)

        // Navigate only if carousel was created and reference image exists
        if let carousel = appState.carouselViewModel.currentCarousel,
           carousel.referenceImagePath != nil {
            appState.navigateToCarouselEditor()
        }
    }

    private func retryReferenceImage() async {
        await appState.carouselViewModel.regenerateReferenceImage(context: modelContext)

        // Navigate if reference image now exists
        if let carousel = appState.carouselViewModel.currentCarousel,
           carousel.referenceImagePath != nil {
            appState.carouselViewModel.errorMessage = nil
            appState.navigateToCarouselEditor()
        }
    }

    // MARK: - Example Data

    private let exampleSubjects = [
        "Comment fonctionne la photosynthèse",
        "Pourquoi le ciel est bleu",
        "Les bases de l'investissement"
    ]
}

// MARK: - Supporting Views

private struct RoleIndicator: View {
    let name: String
    let fulfilled: Bool

    var body: some View {
        Text(name)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(fulfilled ? .white : .scTextTertiary)
            .frame(width: 20, height: 20)
            .background(fulfilled ? Color.scSuccess : Color.scSurface)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.scBorder, lineWidth: fulfilled ? 0 : 1)
            )
    }
}

private struct SummaryItem: View {
    let icon: String
    let title: String
    let content: String
    let isValid: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isValid ? .scSuccess : .scTextTertiary)
                Text(title)
                    .font(SCTypography.callout)
                    .foregroundColor(.scText)
            }

            Text(content)
                .font(SCTypography.caption)
                .foregroundColor(isValid ? .scTextSecondary : .scTextTertiary)
                .lineLimit(3)
        }
        .padding(SCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.scCard)
        .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
    }
}

private struct SelectableCharacterCard: View {
    let character: Character
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    if let imagePath = character.imagePath,
                       let image = NSImage(contentsOfFile: imagePath) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 80)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.scSurface)
                            .frame(height: 80)
                            .overlay(
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.scTextTertiary)
                            )
                    }

                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.scPrimary)
                                    .background(Circle().fill(Color.white))
                                    .padding(SCSpacing.xs)
                            }
                            Spacer()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(character.name)
                        .font(SCTypography.caption)
                        .foregroundColor(.scText)
                        .lineLimit(1)

                    Text(character.role.displayName)
                        .font(SCTypography.caption2)
                        .foregroundColor(.scTextTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SCSpacing.sm)
            }
            .background(isSelected ? Color.scCardSelected : Color.scCard)
            .clipShape(RoundedRectangle(cornerRadius: SCRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: SCRadius.sm)
                    .stroke(isSelected ? Color.scPrimary : (isHovered ? Color.scPrimary.opacity(0.5) : Color.scBorder), lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct SelectableBackgroundCard: View {
    let background: Background
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    if let imagePath = background.imagePath,
                       let image = NSImage(contentsOfFile: imagePath) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 100)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.scSurface)
                            .frame(height: 100)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundColor(.scTextTertiary)
                            )
                    }

                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.scPrimary)
                                    .background(Circle().fill(Color.white))
                                    .padding(SCSpacing.xs)
                            }
                            Spacer()
                        }
                    }
                }

                HStack {
                    Text(background.name)
                        .font(SCTypography.caption)
                        .foregroundColor(.scText)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(SCSpacing.sm)
            }
            .background(isSelected ? Color.scCardSelected : Color.scCard)
            .clipShape(RoundedRectangle(cornerRadius: SCRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: SCRadius.sm)
                    .stroke(isSelected ? Color.scPrimary : (isHovered ? Color.scPrimary.opacity(0.5) : Color.scBorder), lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    ProjectSetupView()
        .environment(AppState())
        .modelContainer(for: [Character.self, Background.self, Carousel.self, Slide.self])
}
