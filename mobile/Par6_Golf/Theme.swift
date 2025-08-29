import SwiftUI

extension Color {
    static let golfGreen = Color(red: 0.224, green: 0.573, blue: 0.318)
    static let fairwayGreen = Color(red: 0.318, green: 0.651, blue: 0.408)
    static let deepGreen = Color(red: 0.141, green: 0.451, blue: 0.259)
    static let mintGreen = Color(red: 0.533, green: 0.804, blue: 0.643)
    static let grassGreen = Color(red: 0.471, green: 0.733, blue: 0.549)
    
    static let sandTrap = Color(red: 0.929, green: 0.859, blue: 0.749)
    static let clubGold = Color(red: 0.859, green: 0.729, blue: 0.455)
    static let trophyGold = Color(red: 0.953, green: 0.816, blue: 0.510)
    
    static let scoreRed = Color(red: 0.827, green: 0.294, blue: 0.302)
    static let parOrange = Color(red: 0.945, green: 0.588, blue: 0.275)
    
    static let skyBlue = Color(red: 0.518, green: 0.718, blue: 0.890)
    static let waterHazard = Color(red: 0.329, green: 0.549, blue: 0.753)
    
    static let cardBackground = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let cardShadow = Color.black.opacity(0.05)
    
    static let primaryText = Color(red: 0.102, green: 0.184, blue: 0.122)
    static let secondaryText = Color(red: 0.376, green: 0.459, blue: 0.396)
    
    static var golfGradient: LinearGradient {
        LinearGradient(
            colors: [.golfGreen, .fairwayGreen],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var grassGradient: LinearGradient {
        LinearGradient(
            colors: [.deepGreen, .golfGreen, .fairwayGreen],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [.trophyGold, .clubGold],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(.systemBackground), Color.mintGreen.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct GolfButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundColor(isPrimary ? .white : (isDestructive ? .scoreRed : .golfGreen))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Group {
                    if isPrimary {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.golfGradient)
                    } else if isDestructive {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.scoreRed.opacity(0.3), lineWidth: 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.scoreRed.opacity(0.05))
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.golfGreen.opacity(0.3), lineWidth: 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.golfGreen.opacity(0.05))
                            )
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .shadow(color: isPrimary ? Color.golfGreen.opacity(0.3) : Color.clear, 
                   radius: isPrimary ? 8 : 0, x: 0, y: 4)
    }
}

struct GolfCardStyle: ViewModifier {
    var isHighlighted: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isHighlighted ? Color.mintGreen.opacity(0.08) : Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isHighlighted ? Color.golfGreen.opacity(0.2) : Color.clear, lineWidth: 1)
            )
            .shadow(color: .cardShadow, radius: 8, x: 0, y: 2)
    }
}

extension View {
    func golfCard(isHighlighted: Bool = false) -> some View {
        modifier(GolfCardStyle(isHighlighted: isHighlighted))
    }
}