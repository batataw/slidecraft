# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the project
xcodebuild -project SlideCraft.xcodeproj -scheme SlideCraft -configuration Debug build

# Build for release
xcodebuild -project SlideCraft.xcodeproj -scheme SlideCraft -configuration Release build

# Run tests (when tests are added)
xcodebuild -project SlideCraft.xcodeproj -scheme SlideCraft test
```

## Project Overview

SlideCraft is an AI-native macOS application that transforms a single subject into a visual carousel (6-8 slides) with dialogue between characters, for explanation, education, and storytelling.

**Core Principles:**
- AI-first at every step - no manual creation from scratch
- Human-in-the-loop - user validates each text, can provide feedback for regeneration
- Dialogue-based storytelling with consistent characters
- Regeneration over manual creation

**Output Format:**
- 6-8 slides, image size 1080x1350 (4:5)
- Export: PNG per slide + PDF for complete story

## Simplified Creation Pipeline

| Step | Action | Output |
|------|--------|--------|
| 1 | User enters subject | Subject string |
| 2 | LLM generates scenario | Array of dialogue texts (6-8 slides) |
| 3 | User validates each text | Validated or regenerated with feedback |
| 4 | Visual prompts generated | One prompt per slide |
| 5 | Images generated | One image per slide |
| 6 | Export | PNG slides + PDF |

## Technical Stack

- macOS / Swift / SwiftUI
- MVVM architecture
- Swift 6 concurrency with `@MainActor` default isolation
- SwiftData for persistence
- **LLM**: OpenAI ChatGPT API (gpt-4o)
- **Image Generation**: Gemini API (via NanoBananaService)

## Architecture

```
SlideCraft/
├── SlideCraftApp.swift           # Entry point
├── ContentView.swift             # Main navigation router
├── Models/
│   ├── Carousel.swift            # Main aggregate (subject, slides)
│   └── Slide.swift               # Slide with text, isValidated, visualPrompt, imagePath
├── Views/
│   ├── HomeView.swift            # Project list
│   ├── SubjectInputView.swift    # Subject entry
│   ├── TextValidationView.swift  # Validate/reject each slide text
│   ├── ImageGenerationView.swift # Generate images
│   ├── ExportView.swift          # PNG/PDF export
│   ├── SettingsView.swift        # API keys configuration
│   └── DesignSystem.swift        # UI components
├── ViewModels/
│   ├── AppState.swift            # Navigation state
│   └── CarouselViewModel.swift   # Main orchestrator
├── Services/
│   ├── AIService.swift           # Protocol and DTOs
│   ├── ChatGPTService.swift      # OpenAI implementation
│   ├── NanoBananaService.swift   # Image generation (Gemini)
│   ├── ExportService.swift       # PNG/PDF export
│   └── KeychainService.swift     # API key storage
└── Assets.xcassets/
```

## Data Model

```swift
@Model class Carousel {
    var id: UUID
    var subject: String
    var slides: [Slide]
    var createdAt: Date
    var updatedAt: Date
}

@Model class Slide {
    var id: UUID
    var index: Int
    var text: String              // Dialogue text (e.g., "Marie: C'est fascinant!")
    var isValidated: Bool         // User has approved this text
    var visualPrompt: String?     // Generated prompt for image
    var imagePath: String?        // Path to generated image
}
```

## AI Service Protocol

```swift
protocol AIServiceProtocol {
    func generateScenario(subject: String) async throws -> CarouselScenario
    func regenerateSlideText(subject: String, currentText: String, feedback: String, allSlides: [String]) async throws -> String
    func generateVisualPrompt(slideText: String, slideIndex: Int, totalSlides: Int, subject: String) async throws -> String
}
```

## Navigation Flow

```
Home -> SubjectInput -> TextValidation -> ImageGeneration -> Export
                              ^                    |
                              |____________________|
                              (back navigation)
```

## Swift Concurrency Notes

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` - all types default to MainActor
- Services are marked as `Sendable` for thread safety
- Use `async/await` for all AI API calls

## Explicit Non-Goals

- No blank canvas or freehand drawing
- No manual long-form writing
- No timeline-based video editing
- No direct social media publishing
- No character management (characters are created by LLM per carousel)
