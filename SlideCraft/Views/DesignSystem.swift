//
//  DesignSystem.swift
//  SlideCraft
//
//  Design System: Dark Mode + Vert Émeraude
//

import SwiftUI

// MARK: - Colors

extension Color {
    // Primary - Vert Émeraude
    static let scPrimary = Color(hex: "10B981")
    static let scPrimaryLight = Color(hex: "34D399")
    static let scPrimaryDark = Color(hex: "059669")

    // Secondary - Teal/Cyan accent
    static let scSecondary = Color(hex: "06B6D4")
    static let scSecondaryLight = Color(hex: "22D3EE")

    // Backgrounds - Dark theme
    static let scBackground = Color(hex: "0F0F0F")
    static let scBackgroundSecondary = Color(hex: "1A1A1A")
    static let scSurface = Color(hex: "1F1F1F")
    static let scSurfaceHover = Color(hex: "2A2A2A")

    // Cards - Dark theme
    static let scCard = Color(hex: "252525")
    static let scCardHover = Color(hex: "2F2F2F")
    static let scCardSelected = Color(hex: "1A3A2F")

    // Text - Light on dark
    static let scText = Color(hex: "F5F5F5")
    static let scTextSecondary = Color(hex: "A3A3A3")
    static let scTextTertiary = Color(hex: "737373")
    static let scTextMuted = Color(hex: "525252")

    // Status
    static let scSuccess = Color(hex: "22C55E")
    static let scWarning = Color(hex: "F59E0B")
    static let scError = Color(hex: "EF4444")

    // Utility
    static let scBorder = Color(hex: "333333")
    static let scBorderLight = Color(hex: "404040")
    static let scDivider = Color(hex: "2A2A2A")

    // Accent glow
    static let scGlow = Color(hex: "10B981").opacity(0.3)
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography

struct SCTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 15, weight: .semibold, design: .default)
    static let body = Font.system(size: 14, weight: .regular, design: .default)
    static let callout = Font.system(size: 13, weight: .medium, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
}

// MARK: - Spacing

struct SCSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

struct SCRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let xl: CGFloat = 20
    static let full: CGFloat = 9999
}

// MARK: - Shadows & Glows

extension View {
    func scShadowSm() -> some View {
        self.shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    func scShadowMd() -> some View {
        self.shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
    }

    func scShadowLg() -> some View {
        self.shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)
    }

    func scGlowPrimary() -> some View {
        self.shadow(color: Color.scPrimary.opacity(0.4), radius: 8, x: 0, y: 0)
    }

    func scGlowSecondary() -> some View {
        self.shadow(color: Color.scSecondary.opacity(0.4), radius: 8, x: 0, y: 0)
    }
}

// MARK: - Button Styles

struct SCPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SCTypography.headline)
            .foregroundColor(isEnabled ? .scBackground : .scTextTertiary)
            .padding(.horizontal, SCSpacing.lg)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: SCRadius.md)
                    .fill(isEnabled ? Color.scPrimary : Color.scPrimary.opacity(0.3))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SCSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SCTypography.headline)
            .foregroundColor(.scPrimary)
            .padding(.horizontal, SCSpacing.lg)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: SCRadius.md)
                    .fill(Color.scPrimary.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SCRadius.md)
                    .stroke(Color.scPrimary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SCGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SCTypography.callout)
            .foregroundColor(.scTextSecondary)
            .padding(.horizontal, SCSpacing.md)
            .padding(.vertical, SCSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: SCRadius.sm)
                    .fill(configuration.isPressed ? Color.scSurfaceHover : Color.clear)
            )
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SCDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SCTypography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, SCSpacing.lg)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: SCRadius.md)
                    .fill(Color.scError)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Card View

struct SCCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = SCSpacing.lg
    var selected: Bool = false

    init(padding: CGFloat = SCSpacing.lg, selected: Bool = false, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.selected = selected
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(selected ? Color.scCardSelected : Color.scCard)
            .clipShape(RoundedRectangle(cornerRadius: SCRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: SCRadius.lg)
                    .stroke(selected ? Color.scPrimary.opacity(0.5) : Color.scBorder, lineWidth: 1)
            )
    }
}

// MARK: - Text Field Style

struct SCTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(SCTypography.body)
            .foregroundColor(.scText)
            .padding(SCSpacing.md)
            .background(Color.scSurface)
            .clipShape(RoundedRectangle(cornerRadius: SCRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: SCRadius.md)
                    .stroke(Color.scBorder, lineWidth: 1)
            )
    }
}

// MARK: - Badge

struct SCBadge: View {
    let text: String
    var color: Color = .scPrimary
    var style: BadgeStyle = .filled

    enum BadgeStyle {
        case filled, outline
    }

    var body: some View {
        Text(text)
            .font(SCTypography.caption2)
            .fontWeight(.semibold)
            .foregroundColor(style == .filled ? .scBackground : color)
            .padding(.horizontal, SCSpacing.sm)
            .padding(.vertical, 3)
            .background(
                Group {
                    if style == .filled {
                        Capsule().fill(color)
                    } else {
                        Capsule().stroke(color, lineWidth: 1)
                    }
                }
            )
    }
}

// MARK: - Icon Button

struct SCIconButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 36
    var color: Color = .scTextSecondary

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isHovered ? .scText : color)
                .frame(width: size, height: size)
                .background(isHovered ? Color.scSurfaceHover : Color.scSurface)
                .clipShape(RoundedRectangle(cornerRadius: SCRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: SCRadius.sm)
                        .stroke(Color.scBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Empty State

struct SCEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionLabel: String = ""

    var body: some View {
        VStack(spacing: SCSpacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.scPrimary.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.scPrimary)
            }
            .scGlowPrimary()

            VStack(spacing: SCSpacing.sm) {
                Text(title)
                    .font(SCTypography.title3)
                    .foregroundColor(.scText)

                Text(message)
                    .font(SCTypography.body)
                    .foregroundColor(.scTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if let action = action {
                Button(action: action) {
                    HStack(spacing: SCSpacing.sm) {
                        Image(systemName: "plus")
                        Text(actionLabel)
                    }
                }
                .buttonStyle(SCPrimaryButtonStyle())
                .padding(.top, SCSpacing.sm)
            }
        }
        .padding(SCSpacing.xxl)
    }
}

// MARK: - Progress Indicator

struct SCProgressIndicator: View {
    let message: String

    var body: some View {
        HStack(spacing: SCSpacing.md) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.scPrimary)

            Text(message)
                .font(SCTypography.callout)
                .foregroundColor(.scTextSecondary)
        }
        .padding(.horizontal, SCSpacing.lg)
        .padding(.vertical, SCSpacing.md)
        .background(Color.scSurface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.scBorder, lineWidth: 1)
        )
    }
}

// MARK: - Section Header

struct SCSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.xs) {
            Text(title)
                .font(SCTypography.headline)
                .foregroundColor(.scText)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(SCTypography.caption)
                    .foregroundColor(.scTextTertiary)
            }
        }
    }
}

// MARK: - Divider

struct SCDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.scDivider)
            .frame(height: 1)
    }
}

// MARK: - Avatar Placeholder (for characters)

struct SCAvatar: View {
    let name: String
    var size: CGFloat = 48
    var color: Color = .scPrimary

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: size, height: size)

            Text(name.prefix(1).uppercased())
                .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
    }
}
