//
//  PlayerStatsView.swift
//  Par6_Golf
//
//  Created by Claude on 8/30/25.
//

import SwiftUI

struct PlayerStatsView: View {
    let userId: String
    let handle: String
    let tournamentName: String?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = APIService.shared
    @State private var playerScores: [Score] = []
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var selectedDateRange = DateRange.lastMonth
    
    enum DateRange: String, CaseIterable {
        case lastWeek = "Last 7 Days"
        case lastMonth = "Last 30 Days"
        case lastThreeMonths = "Last 3 Months"
        
        var days: Int {
            switch self {
            case .lastWeek: return 7
            case .lastMonth: return 30
            case .lastThreeMonths: return 90
            }
        }
    }
    
    private var dateRangeStart: Date {
        Calendar.current.date(byAdding: .day, value: -selectedDateRange.days, to: Date()) ?? Date()
    }
    
    private var averageScore: Double {
        guard !playerScores.isEmpty else { return 0 }
        let total = playerScores.reduce(0) { $0 + $1.golfScore }
        return Double(total) / Double(playerScores.count)
    }
    
    private var bestScore: Int? {
        playerScores.map { $0.golfScore }.min()
    }
    
    private var worstScore: Int? {
        playerScores.filter { $0.scoreType != .penalty }.map { $0.golfScore }.max()
    }
    
    private var scoreDistribution: [(String, Int)] {
        let grouped = Dictionary(grouping: playerScores.filter { $0.scoreType != .penalty }) { score -> String in
            switch score.golfScore {
            case -3: return "⛳"
            case -2: return "-2"
            case -1: return "-1"
            case 0: return "E"
            case 1: return "+1"
            case 2: return "+2"
            case 8: return "DNF"
            default: return "+\(score.golfScore)"
            }
        }
        
        return [
            ("⛳", grouped["⛳"]?.count ?? 0),
            ("-2", grouped["-2"]?.count ?? 0),
            ("-1", grouped["-1"]?.count ?? 0),
            ("E", grouped["E"]?.count ?? 0),
            ("+1", grouped["+1"]?.count ?? 0),
            ("+2", grouped["+2"]?.count ?? 0),
            ("DNF", grouped["DNF"]?.count ?? 0)
        ]
    }
    
    private var penaltyCount: Int {
        playerScores.filter { $0.scoreType == .penalty }.count
    }
    
    private func scoreColor(_ golfScore: Int) -> Color {
        switch golfScore {
        case ...(-2): return .excellentScore
        case -1: return .goodScore
        case 0: return .averageScore
        case 1...2: return .secondary
        default: return .poorScore
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
    
    private func scoreString(_ golfScore: Int, isPenalty: Bool = false) -> String {
        switch golfScore {
        case -3: return "⛳"
        case -2: return "-2"
        case -1: return "-1"
        case 0: return "E"
        case 1: return "+1"
        case 2: return "+2"
        case 8: return isPenalty ? "🚫" : "+4"
        default: return "+\(golfScore)"
        }
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
                                Text("@\(handle)")
                                    .font(.title.weight(.bold))
                                    .foregroundColor(.primary)
                                
                                Text("Par 6 Golf Player")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let tournament = tournamentName {
                            // Tournament Badge
                            HStack(spacing: 8) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.golfAccent)
                                
                                Text(tournament)
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
                    }
                    .padding(.top, 20)
                    
                    // Date Range Selector
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Time Period")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        Picker("Date Range", selection: $selectedDateRange) {
                            ForEach(DateRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)
                        .onChange(of: selectedDateRange) { _, _ in
                            Task { await loadPlayerScores() }
                        }
                    }
                    
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.1)
                            Text("Loading stats...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 40)
                    } else if !playerScores.isEmpty {
                        // Key Statistics
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
                                    value: "\(playerScores.filter { $0.scoreType != .penalty }.count)",
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
                                
                                if let worst = worstScore {
                                    CleanStatCard(
                                        title: "Worst Score", 
                                        value: scoreString(worst),
                                        icon: "exclamationmark.triangle",
                                        accentColor: .poorScore
                                    )
                                }
                                
                                if penaltyCount > 0 {
                                    CleanStatCard(
                                        title: "Penalties",
                                        value: "\(penaltyCount)",
                                        icon: "exclamationmark.circle",
                                        accentColor: .red
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Score Distribution  
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Score Distribution")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(scoreDistribution, id: \.0) { score, count in
                                    if count > 0 {
                                        HStack {
                                            Text(score)
                                                .font(.system(.body, design: .monospaced, weight: .semibold))
                                                .frame(width: 40, alignment: .leading)
                                                .foregroundColor(scoreColor(score == "⛳" ? -3 : 
                                                                          score == "E" ? 0 :
                                                                          score == "DNF" ? 8 :
                                                                          Int(score) ?? 0))
                                            
                                            GeometryReader { geometry in
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(scoreColor(score == "⛳" ? -3 : 
                                                                   score == "E" ? 0 :
                                                                   score == "DNF" ? 8 :
                                                                   Int(score) ?? 0).opacity(0.15))
                                                    .frame(width: max(20, CGFloat(count) / CGFloat(playerScores.count) * geometry.size.width))
                                            }
                                            .frame(height: 24)
                                            
                                            Text("\(count)")
                                                .font(.caption.weight(.medium))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(20)
                            .cleanCard()
                            .padding(.horizontal, 20)
                        }
                        
                        // Recent Scores
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Recent Scores")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(playerScores.count) total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(playerScores.sorted(by: { $0.puzzleDate > $1.puzzleDate }).prefix(14), id: \.id) { score in
                                        VStack(spacing: 6) {
                                            Text(formatDate(score.puzzleDate))
                                                .font(.caption2.weight(.medium))
                                                .foregroundColor(.secondary)
                                            
                                            Text(scoreString(score.golfScore, isPenalty: score.scoreType == .penalty))
                                                .font(.title2.weight(.bold))
                                                .foregroundColor(score.scoreType == .penalty ? .red : scoreColor(score.golfScore))
                                        }
                                        .frame(width: 70, height: 65)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(.systemBackground))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(score.scoreType == .penalty ?
                                                       Color.red.opacity(0.3) : scoreColor(score.golfScore).opacity(0.3), lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                    } else {
                        // Empty State
                        VStack(spacing: 24) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 56))
                                .foregroundColor(.golfAccent.opacity(0.6))
                            
                            VStack(spacing: 8) {
                                Text("No Scores Found")
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(.primary)
                                
                                Text("This player hasn't submitted any scores in this time period.")
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
            .navigationTitle("Player Stats")
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
            Task { await loadPlayerScores() }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadPlayerScores() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            let endDate = Date()
            let startDate = dateRangeStart
            
            playerScores = try await apiService.getPlayerScores(
                userId: userId,
                startDate: formatter.string(from: startDate),
                endDate: formatter.string(from: endDate)
            )
        } catch {
            alertMessage = "Failed to load player scores: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// MARK: - Clean Supporting Views

#Preview {
    PlayerStatsView(
        userId: "test-user-id",
        handle: "testplayer",
        tournamentName: "Summer Championship"
    )
}