import SwiftUI

extension Color {
    // Primary golf accent color - minimal use for highlights only
    static let golfAccent = Color(red: 0.224, green: 0.573, blue: 0.318)
    
    // Score colors for visual feedback
    static let excellentScore = Color.green
    static let goodScore = Color(red: 0.318, green: 0.651, blue: 0.408)
    static let averageScore = Color.orange
    static let poorScore = Color.red
    
    // Achievement colors
    static let achievementGold = Color(red: 0.953, green: 0.816, blue: 0.510)
    
    // Keep legacy colors for backward compatibility but simplified
    static let golfGreen = golfAccent
    static let fairwayGreen = goodScore
    static let scoreRed = poorScore
    static let parOrange = averageScore
    static let trophyGold = achievementGold
    static let mintGreen = Color.mint
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
}

// MARK: - Clean iOS-Standard Card Style
struct CleanCardStyle: ViewModifier {
    var isHighlighted: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHighlighted ? Color.golfAccent : Color(.systemGray5), lineWidth: isHighlighted ? 1.5 : 0.5)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Clean Stat Card Style
struct StatCardStyle: ViewModifier {
    var accentColor: Color = .golfAccent
    var isHighlighted: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHighlighted ? accentColor : Color(.systemGray6), lineWidth: isHighlighted ? 1.5 : 0.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Button Style (Simplified)
struct GolfButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundColor(isPrimary ? .white : (isDestructive ? .red : .golfAccent))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPrimary ? Color.golfAccent : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isPrimary ? Color.clear : (isDestructive ? Color.red : Color.golfAccent), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .shadow(color: Color.black.opacity(0.08), radius: isPrimary ? 4 : 0, x: 0, y: isPrimary ? 2 : 0)
    }
}

// MARK: - Reusable Components
struct CleanStatCard: View {
    let title: String
    let value: String
    let icon: String
    let accentColor: Color
    var isHighlighted: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon or Emoji
            if icon.count == 1 && icon.unicodeScalars.first?.properties.isEmoji == true {
                Text(icon)
                    .font(.system(size: 28))
            } else {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(accentColor)
            }
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cleanCard(isHighlighted: isHighlighted)
    }
}

// MARK: - View Extensions
extension View {
    func cleanCard(isHighlighted: Bool = false) -> some View {
        modifier(CleanCardStyle(isHighlighted: isHighlighted))
    }
    
    func statCard(accentColor: Color = .golfAccent, isHighlighted: Bool = false) -> some View {
        modifier(StatCardStyle(accentColor: accentColor, isHighlighted: isHighlighted))
    }
    
    // Keep legacy method for backward compatibility
    func golfCard(isHighlighted: Bool = false) -> some View {
        modifier(CleanCardStyle(isHighlighted: isHighlighted))
    }
}