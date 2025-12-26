//
//  CarouselEditorView.swift
//  SlideCraft
//
//  Consolidated editor view with tabs for texts and images

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum EditorTab: String, CaseIterable {
    case texts = "Textes"
    case images = "Images"

    var icon: String {
        switch self {
        case .texts: return "text.quote"
        case .images: return "photo.stack"
        }
    }
}

struct CarouselEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var currentTab: EditorTab = .texts

    // Text editing state
    @State private var feedbackText: String = ""
    @State private var showFeedbackField: Bool = false
    @State private var showGlobalFeedback: Bool = false
    @State private var globalFeedbackText: String = ""

    // Image editing state
    @State private var editablePrompt: String = ""
    @State private var isExporting: Bool = false

    // Social description sheet
    @State private var showSocialDescriptionSheet: Bool = false

    private let exportService = ExportService()

    private var viewModel: CarouselViewModel {
        appState.carouselViewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with tab switcher (fixed height)
            header
                .fixedSize(horizontal: false, vertical: true)

            // Content based on tab (fills remaining space)
            HSplitView {
                // Left: Slide list
                slideListPanel
                    .frame(minWidth: 250, maxWidth: 350)

                // Right: Detail panel
                detailPanel
            }
            .frame(maxHeight: .infinity)
        }
        .frame(minWidth: 900, minHeight: 700)
        .background(Color.scBackground)
        .onChange(of: viewModel.currentSlideIndex) {
            loadCurrentSlideData()
        }
        .onChange(of: currentTab) {
            loadCurrentSlideData()
        }
        .onAppear {
            // Start on images tab if all texts are validated
            if viewModel.allSlidesValidated {
                currentTab = .images
            }
            loadCurrentSlideData()
        }
        .sheet(isPresented: $showSocialDescriptionSheet) {
            SocialContentSheet(
                content: viewModel.socialContent,
                isGenerating: viewModel.isGeneratingSocialContent,
                onRegenerate: {
                    Task {
                        await viewModel.generateSocialContent()
                    }
                },
                onClose: {
                    showSocialDescriptionSheet = false
                }
            )
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

            // Tab switcher
            tabSwitcher

            Spacer()

            // Right actions
            rightActions
        }
        .padding(.horizontal, SCSpacing.lg)
        .padding(.vertical, SCSpacing.md)
        .background(Color.scBackgroundSecondary)
        .overlay(alignment: .bottom) {
            SCDivider()
        }
    }

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(EditorTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentTab = tab
                    }
                } label: {
                    HStack(spacing: SCSpacing.xs) {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)

                        // Progress badge
                        if tab == .texts {
                            SCBadge(text: viewModel.validationProgress, color: viewModel.allSlidesValidated ? .scSuccess : .scSecondary)
                        } else {
                            SCBadge(text: viewModel.imageValidationProgress, color: viewModel.allImagesValidated ? .scSuccess : .scSecondary)
                        }
                    }
                    .font(SCTypography.callout)
                    .foregroundColor(currentTab == tab ? .scPrimary : .scTextSecondary)
                    .padding(.horizontal, SCSpacing.lg)
                    .padding(.vertical, SCSpacing.sm)
                    .background(currentTab == tab ? Color.scPrimary.opacity(0.1) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.scSurface)
        .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: SCRadius.md)
                .stroke(Color.scBorder, lineWidth: 1)
        )
    }

    private var rightActions: some View {
        Group {
            if currentTab == .texts && viewModel.allSlidesValidated {
                Button {
                    currentTab = .images
                } label: {
                    HStack(spacing: SCSpacing.sm) {
                        Text("Passer aux images")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(SCPrimaryButtonStyle())
            } else if currentTab == .images {
                if viewModel.allImagesValidated {
                    // Export buttons
                    HStack(spacing: SCSpacing.sm) {
                        Button {
                            showSocialDescriptionSheet = true
                            Task {
                                await viewModel.generateSocialContent()
                            }
                        } label: {
                            HStack(spacing: SCSpacing.xs) {
                                Image(systemName: "text.bubble")
                                Text("Description")
                            }
                        }
                        .buttonStyle(SCGhostButtonStyle())
                        .disabled(viewModel.isGeneratingSocialContent)

                        Button {
                            appState.navigateToTikTokPublish()
                        } label: {
                            HStack(spacing: SCSpacing.xs) {
                                Image(systemName: "play.rectangle.fill")
                                Text("TikTok")
                            }
                        }
                        .buttonStyle(SCSecondaryButtonStyle())

                        Button {
                            exportAsZIP()
                        } label: {
                            HStack(spacing: SCSpacing.xs) {
                                Image(systemName: "photo.on.rectangle")
                                Text("ZIP")
                            }
                        }
                        .buttonStyle(SCSecondaryButtonStyle())
                        .disabled(isExporting)

                        Button {
                            exportAsPDF()
                        } label: {
                            HStack(spacing: SCSpacing.xs) {
                                Image(systemName: "doc.richtext")
                                Text("PDF")
                            }
                        }
                        .buttonStyle(SCPrimaryButtonStyle())
                        .disabled(isExporting)
                    }
                } else if viewModel.hasNoImages {
                    // Generate all button (only if no images exist)
                    Button {
                        Task {
                            await viewModel.generateAllImages(context: modelContext)
                        }
                    } label: {
                        HStack(spacing: SCSpacing.sm) {
                            Image(systemName: "sparkles")
                            Text("Tout générer")
                        }
                    }
                    .buttonStyle(SCPrimaryButtonStyle())
                    .disabled(viewModel.isGenerating)
                } else {
                    Color.clear.frame(width: 100)
                }
            } else {
                Color.clear.frame(width: 100)
            }
        }
    }

    // MARK: - Slide List Panel

    private var slideListPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Reference image section (only for images tab)
            if currentTab == .images {
                referenceImageSection
                SCDivider()
            }

            // Panel header
            HStack {
                Text("Slides")
                    .font(SCTypography.headline)
                    .foregroundColor(.scText)

                Spacer()

                if let carousel = viewModel.currentCarousel {
                    Text("\(carousel.slides.count) slides")
                        .font(SCTypography.caption)
                        .foregroundColor(.scTextTertiary)
                }
            }
            .padding(SCSpacing.md)
            .background(Color.scSurface)

            SCDivider()

            // Slide list
            ScrollView {
                LazyVStack(spacing: SCSpacing.sm) {
                    if let carousel = viewModel.currentCarousel {
                        ForEach(Array(carousel.sortedSlides.enumerated()), id: \.element.id) { index, slide in
                            SlideListItem(
                                index: index,
                                slide: slide,
                                mode: currentTab,
                                isSelected: index == viewModel.currentSlideIndex
                            ) {
                                viewModel.selectSlide(at: index)
                                showFeedbackField = false
                                feedbackText = ""
                            }
                        }
                    }
                }
                .padding(SCSpacing.md)
            }

            // Global regeneration (only for texts tab)
            if currentTab == .texts {
                globalRegenerationSection
            }
        }
        .background(Color.scBackgroundSecondary)
    }

    // MARK: - Reference Image Section

    private var hasReferenceImage: Bool {
        guard let carousel = viewModel.currentCarousel,
              let path = carousel.referenceImagePath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    private var referenceImageSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            HStack {
                Text("Image de référence")
                    .font(SCTypography.caption)
                    .foregroundColor(.scTextTertiary)

                Spacer()

                if hasReferenceImage {
                    Button {
                        Task {
                            await viewModel.regenerateReferenceImage(context: modelContext)
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(SCGhostButtonStyle())
                    .disabled(viewModel.isGenerating)
                }
            }

            if hasReferenceImage,
               let carousel = viewModel.currentCarousel,
               let imagePath = carousel.referenceImagePath,
               let image = NSImage(contentsOfFile: imagePath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: SCRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: SCRadius.sm)
                            .stroke(Color.scBorder, lineWidth: 1)
                    )
            } else {
                // No reference image - show generate button
                Button {
                    Task {
                        await viewModel.regenerateReferenceImage(context: modelContext)
                    }
                } label: {
                    RoundedRectangle(cornerRadius: SCRadius.sm)
                        .fill(Color.scSurface)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            VStack(spacing: SCSpacing.sm) {
                                if viewModel.isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text(viewModel.generationProgress)
                                        .font(SCTypography.caption)
                                        .foregroundColor(.scTextTertiary)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 20))
                                        .foregroundColor(.scPrimary)
                                    Text("Générer l'image")
                                        .font(SCTypography.caption)
                                        .foregroundColor(.scPrimary)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGenerating)
            }
        }
        .padding(SCSpacing.md)
        .background(Color.scSurface)
    }

    // MARK: - Global Regeneration Section

    private var globalRegenerationSection: some View {
        VStack(spacing: SCSpacing.md) {
            SCDivider()

            if showGlobalFeedback {
                VStack(alignment: .leading, spacing: SCSpacing.sm) {
                    Text("Nouvelle consigne pour tout le dialogue")
                        .font(SCTypography.caption)
                        .foregroundColor(.scTextTertiary)

                    TextEditor(text: $globalFeedbackText)
                        .font(SCTypography.body)
                        .foregroundColor(.scText)
                        .scrollContentBackground(.hidden)
                        .frame(height: 80)
                        .padding(SCSpacing.sm)
                        .background(Color.scSurface)
                        .clipShape(RoundedRectangle(cornerRadius: SCRadius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: SCRadius.sm)
                                .stroke(Color.scSecondary.opacity(0.5), lineWidth: 1)
                        )

                    HStack {
                        Button("Annuler") {
                            showGlobalFeedback = false
                            globalFeedbackText = ""
                        }
                        .buttonStyle(SCGhostButtonStyle())

                        Spacer()

                        Button {
                            Task {
                                await regenerateAll()
                            }
                        } label: {
                            HStack(spacing: SCSpacing.xs) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Tout régénérer")
                            }
                            .font(SCTypography.caption)
                        }
                        .buttonStyle(SCSecondaryButtonStyle())
                        .disabled(globalFeedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
                    }
                }
            } else {
                Button {
                    showGlobalFeedback = true
                } label: {
                    HStack(spacing: SCSpacing.sm) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Revoir tout le scénario")
                    }
                    .font(SCTypography.callout)
                    .foregroundColor(.scTextSecondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGenerating)
            }
        }
        .padding(SCSpacing.md)
        .background(Color.scSurface)
    }

    // MARK: - Detail Panel

    private var detailPanel: some View {
        Group {
            if currentTab == .texts {
                textDetailPanel
            } else {
                imageDetailPanel
            }
        }
        .background(Color.scBackground)
    }

    // MARK: - Text Detail Panel

    private var textDetailPanel: some View {
        VStack(spacing: 0) {
            if let slide = viewModel.currentSlide {
                ScrollView {
                    VStack(spacing: SCSpacing.xl) {
                        // Slide number
                        HStack {
                            SCBadge(
                                text: "Slide \(viewModel.currentSlideIndex + 1)",
                                color: slide.isValidated ? .scSuccess : .scSecondary
                            )

                            if slide.isValidated {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.scSuccess)
                                Text("Validé")
                                    .font(SCTypography.caption)
                                    .foregroundColor(.scSuccess)
                            }

                            Spacer()

                            if !showFeedbackField {
                                Button {
                                    showFeedbackField = true
                                } label: {
                                    HStack(spacing: SCSpacing.xs) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text("Modifier")
                                    }
                                    .font(SCTypography.caption)
                                }
                                .buttonStyle(SCGhostButtonStyle())
                                .disabled(viewModel.isGenerating)
                            }
                        }

                        // Text display
                        VStack(alignment: .leading, spacing: SCSpacing.md) {
                            Text("Texte du dialogue")
                                .font(SCTypography.caption)
                                .foregroundColor(.scTextTertiary)

                            Text(slide.text)
                                .font(SCTypography.title2)
                                .foregroundColor(.scText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(SCSpacing.lg)
                                .background(Color.scCard)
                                .clipShape(RoundedRectangle(cornerRadius: SCRadius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: SCRadius.lg)
                                        .stroke(Color.scBorder, lineWidth: 1)
                                )
                        }

                        // Feedback field
                        if showFeedbackField {
                            feedbackSection
                        }

                        // Progress/Error
                        statusSection

                        Spacer(minLength: SCSpacing.xxl)
                    }
                    .padding(SCSpacing.xl)
                }

                // Action buttons
                if !slide.isValidated && !showFeedbackField {
                    textActionButtons
                }
            } else {
                emptySlideState
            }
        }
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.md) {
            Text("Expliquez pourquoi ce texte ne convient pas")
                .font(SCTypography.caption)
                .foregroundColor(.scTextTertiary)

            TextEditor(text: $feedbackText)
                .font(SCTypography.body)
                .foregroundColor(.scText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(SCSpacing.md)
                .background(Color.scSurface)
                .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: SCRadius.md)
                        .stroke(Color.scWarning.opacity(0.5), lineWidth: 1)
                )

            HStack {
                Button("Annuler") {
                    showFeedbackField = false
                    feedbackText = ""
                }
                .buttonStyle(SCGhostButtonStyle())

                Spacer()

                Button {
                    Task {
                        await rejectSlide()
                    }
                } label: {
                    HStack(spacing: SCSpacing.sm) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Régénérer")
                    }
                }
                .buttonStyle(SCSecondaryButtonStyle())
                .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
            }
        }
    }

    private var textActionButtons: some View {
        HStack(spacing: SCSpacing.lg) {
            Button {
                showFeedbackField = true
            } label: {
                HStack(spacing: SCSpacing.sm) {
                    Image(systemName: "xmark")
                    Text("Refuser")
                }
            }
            .buttonStyle(SCSecondaryButtonStyle())

            Button {
                validateSlide()
            } label: {
                HStack(spacing: SCSpacing.sm) {
                    Image(systemName: "checkmark")
                    Text("Valider")
                }
            }
            .buttonStyle(SCPrimaryButtonStyle())
        }
        .padding(SCSpacing.lg)
        .background(Color.scBackgroundSecondary)
        .overlay(alignment: .top) {
            SCDivider()
        }
    }

    // MARK: - Image Detail Panel

    private var imageDetailPanel: some View {
        VStack(spacing: 0) {
            if let slide = viewModel.currentSlide {
                ScrollView {
                    VStack(spacing: SCSpacing.lg) {
                        // Slide header
                        HStack {
                            SCBadge(text: "Slide \(viewModel.currentSlideIndex + 1)", color: .scSecondary)

                            if slide.isImageValidated {
                                HStack(spacing: SCSpacing.xs) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.scSuccess)
                                    Text("Validé")
                                        .font(SCTypography.caption)
                                        .foregroundColor(.scSuccess)
                                }
                            }

                            Spacer()
                        }

                        // Image preview
                        imagePreview(for: slide)

                        // Dialogue text (read-only)
                        VStack(alignment: .leading, spacing: SCSpacing.sm) {
                            Text("Dialogue")
                                .font(SCTypography.caption)
                                .foregroundColor(.scTextTertiary)

                            Text(slide.text)
                                .font(SCTypography.body)
                                .foregroundColor(.scText)
                                .padding(SCSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.scCard)
                                .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
                        }

                        // Editable prompt
                        VStack(alignment: .leading, spacing: SCSpacing.sm) {
                            Text("Prompt visuel (modifiable)")
                                .font(SCTypography.caption)
                                .foregroundColor(.scTextTertiary)

                            TextEditor(text: $editablePrompt)
                                .font(SCTypography.body)
                                .scrollContentBackground(.hidden)
                                .padding(SCSpacing.md)
                                .frame(minHeight: 100)
                                .background(Color.scSurface)
                                .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: SCRadius.md)
                                        .stroke(Color.scBorder, lineWidth: 1)
                                )
                        }

                        // Action buttons
                        imageActionButtons(for: slide)

                        Spacer(minLength: SCSpacing.xl)
                    }
                    .padding(SCSpacing.xl)
                }

                // Status bar
                statusSection
            } else {
                emptySlideState
            }
        }
    }

    @ViewBuilder
    private func imagePreview(for slide: Slide) -> some View {
        if let imagePath = slide.imagePath,
           let image = NSImage(contentsOfFile: imagePath) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: SCRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: SCRadius.lg)
                        .stroke(slide.isImageValidated ? Color.scSuccess : Color.scBorder, lineWidth: slide.isImageValidated ? 2 : 1)
                )
                .scShadowMd()
                .frame(maxHeight: 400)
        } else {
            RoundedRectangle(cornerRadius: SCRadius.lg)
                .fill(Color.scSurface)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    VStack(spacing: SCSpacing.md) {
                        if viewModel.isGenerating {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.scPrimary)
                            Text(viewModel.generationProgress)
                                .font(SCTypography.caption)
                                .foregroundColor(.scTextTertiary)
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundColor(.scTextTertiary)
                            Text("Aucune image générée")
                                .font(SCTypography.caption)
                                .foregroundColor(.scTextTertiary)
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SCRadius.lg)
                        .stroke(Color.scBorder, lineWidth: 1)
                )
                .frame(maxHeight: 400)
        }
    }

    @ViewBuilder
    private func imageActionButtons(for slide: Slide) -> some View {
        HStack(spacing: SCSpacing.md) {
            Button {
                Task {
                    await viewModel.generateImageForCurrentSlide(prompt: editablePrompt, context: modelContext)
                }
            } label: {
                HStack(spacing: SCSpacing.sm) {
                    Image(systemName: slide.imagePath != nil ? "arrow.triangle.2.circlepath" : "sparkles")
                    Text(slide.imagePath != nil ? "Régénérer l'image" : "Générer l'image")
                }
            }
            .buttonStyle(SCSecondaryButtonStyle())
            .disabled(viewModel.isGenerating || editablePrompt.isEmpty)

            Spacer()

            if slide.imagePath != nil && !slide.isImageValidated {
                Button {
                    viewModel.validateCurrentImage(context: modelContext)
                } label: {
                    HStack(spacing: SCSpacing.sm) {
                        Image(systemName: "checkmark")
                        Text("Valider et continuer")
                    }
                }
                .buttonStyle(SCPrimaryButtonStyle())
                .disabled(viewModel.isGenerating)
            }

            if slide.isImageValidated {
                HStack(spacing: SCSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.scSuccess)
                    Text("Image validée")
                        .font(SCTypography.callout)
                        .foregroundColor(.scSuccess)
                }
            }
        }
    }

    // MARK: - Shared Components

    private var statusSection: some View {
        Group {
            if viewModel.isGenerating {
                HStack {
                    SCProgressIndicator(message: viewModel.generationProgress)
                    Spacer()
                }
                .padding(SCSpacing.lg)
                .background(Color.scBackgroundSecondary)
                .overlay(alignment: .top) {
                    SCDivider()
                }
            }

            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.scError)
                    Text(error)
                        .font(SCTypography.caption)
                        .foregroundColor(.scError)
                    Spacer()
                    Button("Fermer") {
                        viewModel.errorMessage = nil
                    }
                    .buttonStyle(SCGhostButtonStyle())
                }
                .padding(SCSpacing.md)
                .background(Color.scError.opacity(0.1))
            }
        }
    }

    private var emptySlideState: some View {
        SCEmptyState(
            icon: currentTab == .texts ? "doc.text" : "photo",
            title: "Aucun slide",
            message: "Sélectionnez un slide dans la liste"
        )
    }

    // MARK: - Actions

    private func loadCurrentSlideData() {
        guard let slide = viewModel.currentSlide else {
            editablePrompt = ""
            return
        }

        if currentTab == .images {
            if let existingPrompt = slide.visualPrompt, !existingPrompt.isEmpty {
                editablePrompt = existingPrompt
            } else {
                editablePrompt = generateFormattedPrompt(from: slide.text)
            }
        }
    }

    private func validateSlide() {
        viewModel.validateCurrentSlide()
        showFeedbackField = false
        feedbackText = ""
    }

    private func rejectSlide() async {
        await viewModel.rejectCurrentSlide(feedback: feedbackText, context: modelContext)
        showFeedbackField = false
        feedbackText = ""
    }

    private func regenerateAll() async {
        await viewModel.regenerateAllSlides(feedback: globalFeedbackText, context: modelContext)
        showGlobalFeedback = false
        globalFeedbackText = ""
    }

    private func generateFormattedPrompt(from dialogueText: String) -> String {
        let speakerName = dialogueText.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? ""
        let dialogueContent = dialogueText.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)

        let allCharacterNames = extractAllCharacterNames()
        let otherCharacters = allCharacterNames.filter { $0 != speakerName }

        var prompt = """
        ⚠️ INSTRUCTION CRITIQUE - ATTRIBUTION DU DIALOGUE :

        Le personnage nommé "\(speakerName)" est CELUI QUI PARLE.
        LA BULLE DE DIALOGUE doit pointer UNIQUEMENT vers \(speakerName).

        TEXTE DANS LA BULLE : "\(dialogueContent)"
        """

        if !otherCharacters.isEmpty {
            prompt += """


            AUTRES PERSONNAGES : \(otherCharacters.joined(separator: ", "))
            ⚠️ Ces personnages N'ONT PAS de bulle de dialogue. Ils écoutent et réagissent.
            """
        }

        prompt += """


        COMPOSITION : \(speakerName) est mis en avant, bouche ouverte en train de parler.
        Les autres personnages ont la bouche fermée et écoutent.
        """

        return prompt
    }

    private func extractAllCharacterNames() -> [String] {
        guard let carousel = viewModel.currentCarousel else { return [] }

        var names = Set<String>()
        for slide in carousel.sortedSlides {
            if let name = slide.text.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces),
               !name.isEmpty {
                names.insert(name)
            }
        }
        return Array(names)
    }

    // MARK: - Export Methods

    private func generateExportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "SlideCraft_\(formatter.string(from: Date()))"
    }

    private func exportAsPDF() {
        guard let carousel = viewModel.currentCarousel else { return }

        let savePanel = NSSavePanel()
        savePanel.title = "Enregistrer le PDF"
        savePanel.nameFieldStringValue = "\(generateExportFilename()).pdf"
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }

            isExporting = true

            Task {
                do {
                    try await exportService.exportAsPDF(carousel: carousel, to: url)
                    await MainActor.run {
                        isExporting = false
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                } catch {
                    await MainActor.run {
                        isExporting = false
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func exportAsZIP() {
        guard let carousel = viewModel.currentCarousel else { return }

        let savePanel = NSSavePanel()
        savePanel.title = "Enregistrer les images"
        savePanel.nameFieldStringValue = "\(generateExportFilename()).zip"
        savePanel.allowedContentTypes = [.zip]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }

            isExporting = true

            Task {
                do {
                    try await exportService.exportAsZIP(carousel: carousel, to: url)
                    await MainActor.run {
                        isExporting = false
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                } catch {
                    await MainActor.run {
                        isExporting = false
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

// MARK: - Slide List Item

private struct SlideListItem: View {
    let index: Int
    let slide: Slide
    let mode: EditorTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var isValidated: Bool {
        mode == .texts ? slide.isValidated : slide.isImageValidated
    }

    private var statusIcon: String {
        if isValidated {
            return "checkmark.circle.fill"
        } else if mode == .images && slide.imagePath != nil {
            return "circle.dashed"
        } else {
            return "circle"
        }
    }

    private var statusColor: Color {
        if isValidated {
            return .scSuccess
        } else if mode == .images && slide.imagePath != nil {
            return .scWarning
        } else {
            return .scTextTertiary
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: SCSpacing.md) {
                // Thumbnail or status indicator
                if mode == .images, let imagePath = slide.imagePath, let image = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: SCRadius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: SCRadius.sm)
                                .stroke(isValidated ? Color.scSuccess : Color.clear, lineWidth: 2)
                        )
                } else {
                    ZStack {
                        Circle()
                            .fill(isValidated ? Color.scSuccess.opacity(0.2) : Color.scSurface)
                            .frame(width: 32, height: 32)

                        if isValidated {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.scSuccess)
                        } else {
                            Text("\(index + 1)")
                                .font(SCTypography.callout)
                                .foregroundColor(.scTextSecondary)
                        }
                    }
                }

                // Text preview
                VStack(alignment: .leading, spacing: 2) {
                    Text("Slide \(index + 1)")
                        .font(SCTypography.caption)
                        .foregroundColor(.scTextTertiary)

                    Text(slide.text)
                        .font(SCTypography.body)
                        .foregroundColor(.scText)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: statusIcon)
                    .font(.system(size: 10))
                    .foregroundColor(statusColor)
            }
            .padding(SCSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: SCRadius.md)
                    .fill(isSelected ? Color.scCardSelected : (isHovered ? Color.scCardHover : Color.scCard))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SCRadius.md)
                    .stroke(isSelected ? Color.scPrimary.opacity(0.5) : Color.scBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Social Content Sheet

private struct SocialContentSheet: View {
    let content: SocialContent?
    let isGenerating: Bool
    let onRegenerate: () -> Void
    let onClose: () -> Void

    @State private var copiedField: CopiedField?

    private enum CopiedField {
        case title, description
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Publication réseaux sociaux")
                    .font(SCTypography.headline)
                    .foregroundColor(.scText)

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.scTextTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(SCSpacing.lg)
            .background(Color.scBackgroundSecondary)
            .overlay(alignment: .bottom) {
                SCDivider()
            }

            // Content
            ScrollView {
                VStack(spacing: SCSpacing.xl) {
                    if isGenerating {
                        VStack(spacing: SCSpacing.md) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.scPrimary)
                            Text("Génération du contenu...")
                                .font(SCTypography.body)
                                .foregroundColor(.scTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SCSpacing.xxl)
                    } else if let content = content {
                        // Title section
                        VStack(alignment: .leading, spacing: SCSpacing.sm) {
                            HStack {
                                Text("Titre")
                                    .font(SCTypography.caption)
                                    .foregroundColor(.scTextTertiary)

                                Spacer()

                                if copiedField == .title {
                                    HStack(spacing: SCSpacing.xs) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10))
                                        Text("Copié")
                                            .font(SCTypography.caption)
                                    }
                                    .foregroundColor(.scSuccess)
                                    .transition(.opacity)
                                }

                                Button {
                                    copyToClipboard(content.title, field: .title)
                                } label: {
                                    HStack(spacing: SCSpacing.xs) {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copier")
                                    }
                                    .font(SCTypography.caption)
                                }
                                .buttonStyle(SCGhostButtonStyle())
                            }

                            Text(content.title)
                                .font(SCTypography.title3)
                                .foregroundColor(.scText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(SCSpacing.md)
                                .background(Color.scCard)
                                .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: SCRadius.md)
                                        .stroke(Color.scBorder, lineWidth: 1)
                                )
                        }

                        // Description section
                        VStack(alignment: .leading, spacing: SCSpacing.sm) {
                            HStack {
                                Text("Description & Hashtags")
                                    .font(SCTypography.caption)
                                    .foregroundColor(.scTextTertiary)

                                Spacer()

                                if copiedField == .description {
                                    HStack(spacing: SCSpacing.xs) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10))
                                        Text("Copié")
                                            .font(SCTypography.caption)
                                    }
                                    .foregroundColor(.scSuccess)
                                    .transition(.opacity)
                                }

                                Button {
                                    copyToClipboard(content.description, field: .description)
                                } label: {
                                    HStack(spacing: SCSpacing.xs) {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copier")
                                    }
                                    .font(SCTypography.caption)
                                }
                                .buttonStyle(SCGhostButtonStyle())
                            }

                            Text(content.description)
                                .font(SCTypography.body)
                                .foregroundColor(.scText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(SCSpacing.md)
                                .background(Color.scCard)
                                .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: SCRadius.md)
                                        .stroke(Color.scBorder, lineWidth: 1)
                                )
                        }
                    } else {
                        SCEmptyState(
                            icon: "text.bubble",
                            title: "Aucun contenu",
                            message: "Cliquez sur Régénérer pour créer le contenu"
                        )
                    }
                }
                .padding(SCSpacing.lg)
            }

            // Actions
            HStack {
                Button {
                    onRegenerate()
                } label: {
                    HStack(spacing: SCSpacing.sm) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Régénérer")
                    }
                }
                .buttonStyle(SCSecondaryButtonStyle())
                .disabled(isGenerating)

                Spacer()
            }
            .padding(SCSpacing.lg)
            .background(Color.scBackgroundSecondary)
            .overlay(alignment: .top) {
                SCDivider()
            }
        }
        .frame(width: 520, height: 480)
        .background(Color.scBackground)
    }

    private func copyToClipboard(_ text: String, field: CopiedField) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        withAnimation {
            copiedField = field
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                if copiedField == field {
                    copiedField = nil
                }
            }
        }
    }
}

#Preview {
    CarouselEditorView()
        .environment(AppState())
        .modelContainer(for: [Carousel.self, Slide.self, Character.self])
}
