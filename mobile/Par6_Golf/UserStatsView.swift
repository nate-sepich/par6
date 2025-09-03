//
//  UserStatsView.swift
//  Par6_Golf
//
//  Created by Claude on 8/31/25.
//

import SwiftUI

struct UserStatsView: View {
    @StateObject private var apiService = APIService.shared
    @State private var userScores: [Score] = []
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var selectedDateRange = DateRange.lastMonth
    @State private var showingPublicProfile = false
    
    enum DateRange: String, CaseIterable {
        case lastWeek = "Last 7 Days"
        case lastMonth = "Last 30 Days"
        case lastThreeMonths = "Last 3 Months"
        case allTime = "All Time"
        
        var days: Int? {
            switch self {
            case .lastWeek: return 7
            case .lastMonth: return 30
            case .lastThreeMonths: return 90
            case .allTime: return nil
            }
        }
    }
    
    private var dateRangeStart: Date {
        guard let days = selectedDateRange.days else {
            return Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
        }
        return Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
    
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
    
    private var worstScore: Int? {
        playedRounds.map { $0.golfScore }.max()
    }
    
    private var totalPenalties: Int {
        userScores.filter { $0.scoreType == .penalty }.count
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
    
    private var parCount: Int {
        playedRounds.filter { $0.golfScore == 0 }.count
    }
    
    private var underParRounds: Int {
        playedRounds.filter { $0.golfScore < 0 }.count
    }
    
    private var scoreDistribution: [(String, Int)] {
        let grouped = Dictionary(grouping: playedRounds) { score -> String in
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
        
        let aces = grouped["⛳"]?.count ?? 0
        let eagles = grouped["-2"]?.count ?? 0
        let birdies = grouped["-1"]?.count ?? 0
        let pars = grouped["E"]?.count ?? 0
        let bogeys = grouped["+1"]?.count ?? 0
        let doubleBogeys = grouped["+2"]?.count ?? 0
        let dnfs = grouped["DNF"]?.count ?? 0
        
        let distribution = [
            ("⛳", aces),
            ("-2", eagles),
            ("-1", birdies),
            ("E", pars),
            ("+1", bogeys),
            ("+2", doubleBogeys),
            ("DNF", dnfs)
        ]
        
        return distribution.filter { $0.1 > 0 }
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
                                if let user = apiService.currentUser {
                                    Text("@\(user.handle)")
                                        .font(.title.weight(.bold))
                                        .foregroundColor(.primary)
                                } else {
                                    Text("My Stats")
                                        .font(.title.weight(.bold))
                                        .foregroundColor(.primary)
                                }
                                
                                HStack(spacing: 6) {
                                    Text("Par 6 Golf Player")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: {
                                        if apiService.currentUser != nil {
                                            showingPublicProfile = true
                                        }
                                    }) {
                                        Image(systemName: "person.circle")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.golfAccent)
                                    }
                                }
                            }
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
                            Task { await loadUserScores() }
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
                    } else if !userScores.isEmpty {
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
                                
                                if let worst = worstScore {
                                    CleanStatCard(
                                        title: "Worst Score", 
                                        value: scoreString(worst),
                                        icon: "exclamationmark.triangle",
                                        accentColor: .poorScore
                                    )
                                }
                                
                                if totalPenalties > 0 {
                                    CleanStatCard(
                                        title: "Penalties",
                                        value: "\(totalPenalties)",
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
                                                    .frame(width: max(20, CGFloat(count) / CGFloat(playedRounds.count) * geometry.size.width))
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
                                Text("\(userScores.count) total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(userScores.sorted(by: { $0.puzzleDate > $1.puzzleDate }).prefix(14), id: \.id) { score in
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
                                
                                Text("You haven't submitted any scores in this time period.")
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
            .navigationTitle("My Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Handle close action if needed
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
        .sheet(isPresented: $showingPublicProfile) {
            if let user = apiService.currentUser {
                PublicProfileView(user: user)
            }
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
            let startDate = dateRangeStart
            
            userScores = try await apiService.getUserScores(
                startDate: formatter.string(from: startDate),
                endDate: formatter.string(from: endDate)
            )
        } catch {
            alertMessage = "Failed to load your scores: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// MARK: - Clean Supporting Views

#Preview {
    UserStatsView()
}