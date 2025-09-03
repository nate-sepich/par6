//
//  PublicProfileView.swift
//  Par6_Golf
//
//  Created by Claude on 8/31/25.
//

import SwiftUI

struct PublicProfileView: View {
    let user: User
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = APIService.shared
    @State private var userScores: [Score] = []
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    private var playedRounds: [Score] {
        userScores.filter { $0.scoreType != .penalty }
    }
    
    private var averageScore: Double {
        guard !playedRounds.isEmpty else { return 0 }
        let total = playedRounds.reduce(0) { $0 + $1.golfScore }
        return Double(total) / Double(playedRounds.count)
    }
    
    private var bestScore: Int? {
        playedRounds.map { $0.golfScore }.min()
    }
    
    private var aceCount: Int {
        playedRounds.filter { $0.golfScore == -3 }.count
    }
    
    private var eagleCount: Int {
        playedRounds.filter { $0.golfScore == -2 }.count
    }
    
    private var birdieCount: Int {
        playedRounds.filter { $0.golfScore == -1 }.count
    }
    
    private var underParRounds: Int {
        playedRounds.filter { $0.golfScore < 0 }.count
    }
    
    private var recentHighlights: [Score] {
        let sortedScores = playedRounds.sorted { $0.puzzleDate > $1.puzzleDate }
        let bestRecentScores = sortedScores.prefix(10).filter { $0.golfScore <= 0 }
        return Array(bestRecentScores.prefix(5))
    }
    
    private var performanceLevel: (title: String, description: String, color: Color, icon: String) {
        if averageScore <= -1.5 {
            return ("Elite Player", "Consistently exceptional performance", .trophyGold, "crown.fill")
        } else if averageScore <= -0.5 {
            return ("Skilled Golfer", "Strong and consistent play", .golfGreen, "star.fill")
        } else if averageScore <= 0.5 {
            return ("Steady Player", "Reliable performance around par", .parOrange, "target")
        } else {
            return ("Developing Player", "Building skills and improving", .mintGreen, "leaf.fill")
        }
    }
    
    private func scoreString(_ golfScore: Int) -> String {
        switch golfScore {
        case -3: return "⛳"
        case -2: return "-2"
        case -1: return "-1"
        case 0: return "E"
        case 1: return "+1"
        case 2: return "+2"
        default: return "+\(golfScore)"
        }
    }
    
    private func scoreColor(_ golfScore: Int) -> Color {
        switch golfScore {
        case ...(-2): return .golfGreen
        case -1: return .fairwayGreen
        case 0: return .parOrange
        case 1...2: return .secondaryText
        default: return .scoreRed
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        return dateString
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Player Header
                    VStack(spacing: 20) {
                        // Avatar and Name
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.golfAccent)
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 36, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 4) {
                                Text("@\(user.handle)")
                                    .font(.title.weight(.bold))
                                    .foregroundColor(.primary)
                                
                                Text("Par 6 Golf Player")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Performance Badge
                        HStack(spacing: 8) {
                            Image(systemName: performanceLevel.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.golfAccent)
                            
                            Text(performanceLevel.title)
                                .font(.callout.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.golfAccent, lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                    }
                    .padding(.top, 20)
                    
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.1)
                            Text("Loading profile...")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondaryText)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 40)
                    } else if !userScores.isEmpty {
                        // Key Achievements
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Key Achievements")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                CleanStatCard(
                                    title: "Aces",
                                    value: "\(aceCount)",
                                    icon: "⛳",
                                    accentColor: .excellentScore,
                                    isHighlighted: aceCount > 0
                                )
                                
                                CleanStatCard(
                                    title: "Eagles",
                                    value: "\(eagleCount)",
                                    icon: "🦅",
                                    accentColor: .excellentScore,
                                    isHighlighted: eagleCount > 0
                                )
                                
                                CleanStatCard(
                                    title: "Birdies",
                                    value: "\(birdieCount)",
                                    icon: "🐦",
                                    accentColor: .goodScore,
                                    isHighlighted: birdieCount > 0
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Performance Overview
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Performance Overview")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                CleanStatCard(
                                    title: "Rounds Played",
                                    value: "\(playedRounds.count)",
                                    icon: "flag.fill",
                                    accentColor: .golfAccent
                                )
                                
                                CleanStatCard(
                                    title: "Average Score",
                                    value: String(format: "%+.1f", averageScore),
                                    icon: "chart.line.uptrend.xyaxis",
                                    accentColor: averageScore <= 0 ? .excellentScore : .averageScore
                                )
                                
                                if let best = bestScore {
                                    CleanStatCard(
                                        title: "Best Score",
                                        value: scoreString(best),
                                        icon: "star.fill",
                                        accentColor: .achievementGold,
                                        isHighlighted: true
                                    )
                                }
                                
                                CleanStatCard(
                                    title: "Under Par Rounds",
                                    value: "\(underParRounds)",
                                    icon: "arrow.down.circle.fill",
                                    accentColor: .excellentScore
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Recent Highlights
                        if !recentHighlights.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Recent Highlights")
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("Best recent rounds")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(recentHighlights, id: \.id) { score in
                                            VStack(spacing: 6) {
                                                Text(formatDate(score.puzzleDate))
                                                    .font(.caption2.weight(.medium))
                                                    .foregroundColor(.secondary)
                                                
                                                Text(scoreString(score.golfScore))
                                                    .font(.title2.weight(.bold))
                                                    .foregroundColor(scoreColor(score.golfScore))
                                            }
                                            .frame(width: 70, height: 65)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color(.systemBackground))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(scoreColor(score.golfScore).opacity(0.3), lineWidth: 1)
                                            )
                                            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        // Player Description
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About This Player")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 16) {
                                HStack(spacing: 12) {
                                    Image(systemName: performanceLevel.icon)
                                        .font(.title2)
                                        .foregroundColor(.golfAccent)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(performanceLevel.description)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        if playedRounds.count >= 10 {
                                            Text("Active player with \(playedRounds.count) rounds completed")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("New to Par 6 Golf")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                
                                if underParRounds > 0 {
                                    Divider()
                                        .background(Color.secondary.opacity(0.3))
                                    
                                    HStack(spacing: 12) {
                                        Image(systemName: "target")
                                            .font(.title2)
                                            .foregroundColor(.excellentScore)
                                            .frame(width: 30)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Consistent Excellence")
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            
                                            let percentage = Int((Double(underParRounds) / Double(playedRounds.count)) * 100)
                                            Text("\(percentage)% of rounds under par")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                            }
                            .padding(20)
                            .cleanCard()
                            .padding(.horizontal, 20)
                        }
                        
                    } else {
                        // Empty State
                        VStack(spacing: 24) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 56))
                                .foregroundColor(.golfAccent.opacity(0.6))
                            
                            VStack(spacing: 8) {
                                Text("New Player")
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(.primary)
                                
                                Text("This player hasn't submitted any scores yet.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 60)
                        .cleanCard()
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Public Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(.golfAccent)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            Task { await loadUserScores() }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadUserScores() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            let endDate = Date()
            // Load last 3 months for public profile
            let startDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
            
            userScores = try await apiService.getPlayerScores(
                userId: user.userId,
                startDate: formatter.string(from: startDate),
                endDate: formatter.string(from: endDate)
            )
        } catch {
            alertMessage = "Failed to load profile data: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// MARK: - Clean Supporting Views

#Preview {
    PublicProfileView(user: User(
        userId: "test-user-id",
        handle: "testplayer",
        createdAt: Date()
    ))
}