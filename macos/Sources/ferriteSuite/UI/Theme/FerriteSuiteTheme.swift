import SwiftUI
import AppKit

public struct FerriteSuiteTheme {
    // Dynamic Accent Colors (Adapting smoothly to Light and Dark modes)
    public static var accentCyan: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.0, green: 0.96, blue: 0.83, alpha: 1.0) // Neon Electric Cyan
                : NSColor(red: 0.02, green: 0.52, blue: 0.78, alpha: 1.0) // Deep Cerulean Cyan
        }))
    }
    
    public static var cyberPurple: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.55, green: 0.25, blue: 0.95, alpha: 1.0)
                : NSColor(red: 0.45, green: 0.18, blue: 0.80, alpha: 1.0)
        }))
    }
    
    public static var flipperOrange: Color {
        Color(red: 1.0, green: 0.42, blue: 0.08)
    }
    
    public static var neonAmber: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 1.0, green: 0.72, blue: 0.01, alpha: 1.0)
                : NSColor(red: 0.85, green: 0.52, blue: 0.0, alpha: 1.0)
        }))
    }
    
    public static var neonRed: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.96, green: 0.26, blue: 0.38, alpha: 1.0)
                : NSColor(red: 0.86, green: 0.15, blue: 0.25, alpha: 1.0)
        }))
    }
    
    public static var neonGreen: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.02, green: 0.84, blue: 0.63, alpha: 1.0)
                : NSColor(red: 0.04, green: 0.62, blue: 0.44, alpha: 1.0)
        }))
    }
    
    // Dynamic Surface Backgrounds
    public static var darkBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0) // Sleek Cyber Charcoal
                : NSColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0) // Crisp Clean Canvas
        }))
    }
    
    public static var cardBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.09, green: 0.11, blue: 0.14, alpha: 1.0) // Dark Glass Card
                : NSColor(white: 1.0, alpha: 1.0) // Pure White Paper Card
        }))
    }
    
    public static var secondaryCardBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.13, green: 0.15, blue: 0.19, alpha: 1.0)
                : NSColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1.0)
        }))
    }
    
    public static var subtleBorder: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 0.22, alpha: 0.8)
                : NSColor(white: 0.82, alpha: 0.9)
        }))
    }
    
    public static var primaryTextColor: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor.white
                : NSColor(red: 0.07, green: 0.09, blue: 0.12, alpha: 1.0)
        }))
    }
    
    public static var secondaryTextColor: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 0.65, alpha: 1.0)
                : NSColor(white: 0.40, alpha: 1.0)
        }))
    }
    
    public static var terminalBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.04, green: 0.05, blue: 0.07, alpha: 0.95)
                : NSColor(red: 0.10, green: 0.12, blue: 0.15, alpha: 0.98)
        }))
    }
    
    public static var codeBlockBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.06, green: 0.08, blue: 0.11, alpha: 1.0)
                : NSColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1.0)
        }))
    }
    
    public static var buttonBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.14, green: 0.16, blue: 0.20, alpha: 1.0)
                : NSColor(red: 0.91, green: 0.92, blue: 0.95, alpha: 1.0)
        }))
    }
}

public struct GlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 12
    
    public func body(content: Content) -> some View {
        content
            .background(FerriteSuiteTheme.cardBackground)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(FerriteSuiteTheme.subtleBorder, lineWidth: 1)
            )
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = 12) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}
