//
//  TikTokPublishView.swift
//  SlideCraft
//
//  WebView-based TikTok publishing with drag & drop assets
//

import SwiftUI
import SwiftData
import WebKit

struct TikTokPublishView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var copiedField: CopiedField?
    @State private var saveTask: Task<Void, Never>?

    private enum CopiedField {
        case title, description
    }

    private var carousel: Carousel? {
        appState.carouselViewModel.currentCarousel
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            HSplitView {
                // Left: Assets panel
                assetsPanel
                    .frame(minWidth: 280, maxWidth: 350)

                // Right: WebView
                TikTokWebView()
                    .frame(minWidth: 400)
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .background(Color.scBackground)
        .onAppear {
            loadDraft()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                appState.navigateToCarouselEditor()
            } label: {
                HStack(spacing: SCSpacing.sm) {
                    Image(systemName: "chevron.left")
                    Text("Retour")
                }
            }
            .buttonStyle(SCGhostButtonStyle())

            Spacer()

            Text("Publier sur TikTok")
                .font(SCTypography.headline)
                .foregroundColor(.scText)

            Spacer()

            HStack(spacing: SCSpacing.xs) {
                Image(systemName: "info.circle")
                Text("Glissez les images dans TikTok")
                    .font(SCTypography.caption)
            }
            .foregroundColor(.scTextTertiary)
        }
        .padding(.horizontal, SCSpacing.lg)
        .padding(.vertical, SCSpacing.md)
        .background(Color.scBackgroundSecondary)
        .overlay(alignment: .bottom) {
            SCDivider()
        }
    }

    // MARK: - Assets Panel

    private var assetsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Images section
            VStack(alignment: .leading, spacing: SCSpacing.md) {
                HStack {
                    Text("Images")
                        .font(SCTypography.headline)
                        .foregroundColor(.scText)
                    Spacer()
                    if let carousel = carousel {
                        Text("\(carousel.slides.count) slides")
                            .font(SCTypography.caption)
                            .foregroundColor(.scTextTertiary)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SCSpacing.sm) {
                        if let carousel = carousel {
                            ForEach(Array(carousel.sortedSlides.enumerated()), id: \.element.id) { index, slide in
                                DraggableSlideImage(slide: slide, index: index)
                            }
                        }
                    }
                    .padding(.vertical, SCSpacing.xs)
                }

                Text("Glissez les images vers TikTok")
                    .font(SCTypography.caption)
                    .foregroundColor(.scTextTertiary)
            }
            .padding(SCSpacing.lg)
            .background(Color.scSurface)

            SCDivider()

            // Title section
            VStack(alignment: .leading, spacing: SCSpacing.sm) {
                HStack {
                    Text("Titre")
                        .font(SCTypography.headline)
                        .foregroundColor(.scText)

                    Spacer()

                    if copiedField == .title {
                        HStack(spacing: SCSpacing.xs) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10))
                            Text("Copié")
                                .font(SCTypography.caption)
                        }
                        .foregroundColor(.scSuccess)
                    }

                    Button {
                        copyToClipboard(title, field: .title)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(SCGhostButtonStyle())
                    .disabled(title.isEmpty)
                }

                TextField("Titre de votre publication...", text: $title)
                    .textFieldStyle(SCTextFieldStyle())
                    .onChange(of: title) {
                        scheduleSave()
                    }
            }
            .padding(SCSpacing.lg)

            SCDivider()

            // Description section
            VStack(alignment: .leading, spacing: SCSpacing.sm) {
                HStack {
                    Text("Description")
                        .font(SCTypography.headline)
                        .foregroundColor(.scText)

                    Spacer()

                    if copiedField == .description {
                        HStack(spacing: SCSpacing.xs) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10))
                            Text("Copié")
                                .font(SCTypography.caption)
                        }
                        .foregroundColor(.scSuccess)
                    }

                    Button {
                        copyToClipboard(description, field: .description)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(SCGhostButtonStyle())
                    .disabled(description.isEmpty)
                }

                TextEditor(text: $description)
                    .font(SCTypography.body)
                    .foregroundColor(.scText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .padding(SCSpacing.sm)
                    .background(Color.scSurface)
                    .clipShape(RoundedRectangle(cornerRadius: SCRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: SCRadius.sm)
                            .stroke(Color.scBorder, lineWidth: 1)
                    )
                    .onChange(of: description) {
                        scheduleSave()
                    }
            }
            .padding(SCSpacing.lg)

            Spacer()

            // Footer
            VStack(spacing: SCSpacing.sm) {
                SCDivider()

                HStack(spacing: SCSpacing.xs) {
                    Image(systemName: "doc.badge.clock")
                        .font(.system(size: 12))
                    Text("Brouillon sauvegardé")
                        .font(SCTypography.caption)
                }
                .foregroundColor(.scTextTertiary)
                .padding(SCSpacing.md)
            }
        }
        .background(Color.scBackgroundSecondary)
    }

    // MARK: - Actions

    private func loadDraft() {
        guard let carousel = carousel else { return }
        title = carousel.tiktokTitle ?? ""
        description = carousel.tiktokDescription ?? ""
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                saveDraft()
            }
        }
    }

    private func saveDraft() {
        guard let carousel = carousel else { return }
        carousel.tiktokTitle = title.isEmpty ? nil : title
        carousel.tiktokDescription = description.isEmpty ? nil : description
        carousel.updatedAt = Date()
        try? modelContext.save()
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

// MARK: - Draggable Slide Image

private struct DraggableSlideImage: View {
    let slide: Slide
    let index: Int

    var body: some View {
        if let imagePath = slide.imagePath,
           let image = NSImage(contentsOfFile: imagePath) {
            VStack(spacing: SCSpacing.xs) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(4/5, contentMode: .fill)
                    .frame(width: 60, height: 75)
                    .clipShape(RoundedRectangle(cornerRadius: SCRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: SCRadius.sm)
                            .stroke(Color.scBorder, lineWidth: 1)
                    )
                    .draggable(image) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(4/5, contentMode: .fill)
                            .frame(width: 60, height: 75)
                            .clipShape(RoundedRectangle(cornerRadius: SCRadius.sm))
                            .opacity(0.8)
                    }

                Text("\(index + 1)")
                    .font(SCTypography.caption2)
                    .foregroundColor(.scTextTertiary)
            }
        }
    }
}

// MARK: - TikTok WebView

struct TikTokWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)

        // Mobile user agent for TikTok upload interface
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        if let url = URL(string: "https://www.tiktok.com/upload") {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

#Preview {
    TikTokPublishView()
        .environment(AppState())
        .modelContainer(for: [Carousel.self, Slide.self])
}
