# TikTok Publishing Feature Design

## Overview

Add direct TikTok Photo Carousel publishing from SlideCraft.

**User flow:**
1. Connect TikTok account once in Settings (OAuth)
2. After generating all carousel images, tap "Publish to TikTok"
3. Configure title and description on dedicated screen
4. Publish directly to TikTok

## Data Model

### Carousel Extension

```swift
@Model class Carousel {
    // Existing fields...

    // TikTok publishing
    var tiktokTitle: String?
    var tiktokDescription: String?
    var tiktokPostId: String?
    var tiktokPublishedAt: Date?
}
```

### TikTokService Protocol

```swift
protocol TikTokServiceProtocol {
    var isAuthenticated: Bool { get }
    func authenticate() async throws
    func disconnect()
    func publishCarousel(
        images: [URL],
        title: String,
        description: String
    ) async throws -> String  // Returns postId
}
```

### Keychain Keys

- `.tiktokAccessToken`
- `.tiktokRefreshToken`

## User Interface

### TikTokPublishView

```
┌─────────────────────────────────────────┐
│  <- Back              Publish to TikTok │
├─────────────────────────────────────────┤
│                                         │
│   [1] [2] [3] [4] [...]                │  <- Horizontal scroll preview
│                                         │
├─────────────────────────────────────────┤
│  Title                                  │
│  ┌─────────────────────────────────────┐│
│  │                                     ││  <- TextField (max ~150 chars)
│  └─────────────────────────────────────┘│
│                                         │
│  Description                            │
│  ┌─────────────────────────────────────┐│
│  │                                     ││  <- TextEditor (max ~2200 chars)
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │            Publish                  ││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

**Behaviors:**
- Pre-fill title/description from saved draft
- Auto-save draft on each keystroke (debounced 500ms)
- Disable "Publish" if title empty or not connected
- Loading indicator during publish

### SettingsView Extension

```
┌─────────────────────────────────────────┐
│  API Keys                               │
│  ├─ OpenAI API Key      ●●●●●●●●       │
│  └─ Gemini API Key      ●●●●●●●●       │
│                                         │
│  Social Networks                        │
│  ├─ TikTok                              │
│  │   [Connect my account]              │  <- Disconnected state
│  │   @username    [Disconnect]         │  <- Connected state
└─────────────────────────────────────────┘
```

### HomeView Status Badges

- Green "Published" badge if `tiktokPostId` exists
- Orange "Draft" badge if `tiktokTitle` exists but not published
- No badge otherwise

## OAuth Flow

1. User taps "Connect my account"
2. Open browser to TikTok OAuth
3. User authorizes app
4. Redirect to `slidecraft://tiktok/callback`
5. Exchange code for access/refresh tokens
6. Store tokens in Keychain

**Token management:**
- Access token: ~24h validity
- Refresh token: ~365 days validity
- Auto-refresh before expiration on publish

## Error Handling

| Error | Behavior |
|-------|----------|
| No network | "No internet connection" + save draft |
| Token expired (refresh fails) | "Session expired, reconnect in Settings" + save draft |
| TikTok API error | Show error detail + save draft |
| Images too large | "Images exceed TikTok limit" |

**Draft persistence:**
- Saved to Carousel in SwiftData
- Persists across app restarts
- Cleared only after successful publish

## Navigation

### AppScreen Extension

```swift
enum AppScreen {
    case home
    case characters
    case backgrounds
    case projectSetup
    case carouselEditor
    case tiktokPublish      // New
}
```

### Access Point

- Button in CarouselEditorView: "Publish to TikTok"
- Only visible when all images are generated
- Disabled with tooltip if not connected to TikTok

## Files to Create/Modify

| File | Action |
|------|--------|
| `Models/Carousel.swift` | Add TikTok fields |
| `Services/TikTokService.swift` | New - OAuth + API |
| `Services/KeychainService.swift` | Add token keys |
| `Views/TikTokPublishView.swift` | New - Publish UI |
| `Views/SettingsView.swift` | Add TikTok section |
| `Views/CarouselEditorView.swift` | Add publish button |
| `Views/HomeView.swift` | Add status badges |
| `ViewModels/AppState.swift` | Add screen + navigation |
| `Info.plist` | URL scheme `slidecraft://` |

## Prerequisites

- TikTok for Developers account
- Registered TikTok app with `video.publish` scope
