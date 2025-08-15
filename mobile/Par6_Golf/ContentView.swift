//
//  ContentView.swift
//  Par6_Golf
//
//  Created by Cole Michael Riddlebarger on 6/4/25.
//

import SwiftUI
import Foundation

// MARK: - Placeholder Views

struct AccoladesView: View {
    var body: some View {
        Text("Personal Accolades")
            .font(.largeTitle)
            .padding()
    }
}

struct PublicServerView: View {
    var body: some View {
        Text("Public Server")
            .font(.largeTitle)
            .padding()
    }
}

struct ComingSoonView: View {
    var body: some View {
        Text("Coming Soon")
            .font(.largeTitle)
            .padding()
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .font(.largeTitle)
            .padding()
    }
}

// Simple placeholders so the app builds
struct GameListView: View {
    var body: some View {
        Text("Games")
            .font(.largeTitle)
            .padding()
    }
}

struct ProfileView: View {
    @AppStorage("myUsername") private var myUsername: String = ""
    var body: some View {
        VStack(spacing: 12) {
            Text("Profile")
                .font(.largeTitle)
            Text("Username: \(myUsername.isEmpty ? "(not set)" : myUsername)")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Main ContentView

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                MainDashboardView()
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }

            GameListView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("Games")
                }

            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .tint(.black)
    }
}

// MARK: - Main Dashboard

struct MainDashboardView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 24) {
                // Top Bar
                HStack {
                    Text("Par6")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding(.leading)
                    Spacer()
                    Text("Wordle Golf")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.green)
                    Spacer()
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                            .padding(.trailing)
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 12)
                .background(Color.white)

                // Quadrants as floating putting greens (buttons)
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        NavigationLink(destination: AccoladesView()) {
                            PuttingGreenBox {
                                VStack {
                                    Text("Personal Accolades")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("🏆 Games Won: 0")
                                        .foregroundColor(.white)
                                    Text("⛳ Best Score: -")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                            }
                        }
                        NavigationLink(destination: ScorecardView()) {
                            PuttingGreenBox {
                                VStack {
                                    Text("Current Scorecards")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("Tap to add today's score")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                            }
                        }
                    }
                    HStack(spacing: 20) {
                        NavigationLink(destination: PublicServerView()) {
                            PuttingGreenBox {
                                VStack {
                                    Text("Public Server")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("Join a public game!")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                            }
                        }
                        NavigationLink(destination: ComingSoonView()) {
                            PuttingGreenBox {
                                VStack {
                                    Text("Coming Soon")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                Spacer()
            }
        }
    }
}

// MARK: - Putting Green Box

struct PuttingGreenBox<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green.opacity(0.85), Color.green]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 6)
            content
                .padding()
        }
        .frame(width: 160, height: 160)
    }
}

// MARK: - Scorecard Model

struct DailyScore: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let score: Int
}

struct PlayerScore: Identifiable, Codable {
    var id = UUID()
    var userID: String
    var playerName: String
    var scores: [DailyScore]
}

struct Game: Identifiable, Codable {
    var id = UUID()
    var startDate: Date
    var players: [PlayerScore]
}

// MARK: - MultiPlayerScorecardStore

class MultiPlayerScorecardStore: ObservableObject {
    @Published var currentGame: Game?
    private let key = "current_golf_game"

    init() {
        load()
        if currentGame == nil {
            // Create a default single-player game for "me"
            currentGame = Game(startDate: Date(), players: [PlayerScore(userID: "me", playerName: "Me", scores: [])])
            save()
        }
    }
    
    var myScores: [DailyScore] {
        currentGame?.players.first(where: { $0.userID == "me" })?.scores ?? []
    }

    func startNewGame(startDate: Date, playerInfos: [(userID: String, name: String)]) {
        let players = playerInfos.map { PlayerScore(userID: $0.userID, playerName: $0.name, scores: []) }
        currentGame = Game(startDate: startDate, players: players)
        save()
    }

    func startNewGame(startDate: Date, playerNames: [String]) {
        let players = playerNames.map { name in
            // Generate unique IDs for provided names; caller can pass explicit IDs via playerInfos if needed
            let userID = UUID().uuidString
            return PlayerScore(userID: userID, playerName: name, scores: [])
        }
        currentGame = Game(startDate: startDate, players: players)
        save()
    }

    func addPlayer(userID: String, name: String) {
        guard var game = currentGame else { return }
        if !game.players.contains(where: { $0.userID == userID }) {
            game.players.append(PlayerScore(userID: userID, playerName: name, scores: []))
            currentGame = game
            save()
        }
    }

    func addScore(for userID: String, date: Date, score: Int) {
        guard var game = currentGame,
              let idx = game.players.firstIndex(where: { $0.userID == userID }) else { return }
        game.players[idx].scores.removeAll { Calendar.current.isDate($0.date, inSameDayAs: date) }
        game.players[idx].scores.append(DailyScore(date: date, score: score))
        game.players[idx].scores.sort { $0.date < $1.date }
        currentGame = game
        save()
    }

    func scoreExists(for player: String, date: Date) -> Bool {
        guard let game = currentGame,
              let idx = game.players.firstIndex(where: { $0.playerName == player || $0.userID == player }) else { return false }
        return game.players[idx].scores.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func overwriteScore(for player: String, date: Date, score: Int) {
        guard var game = currentGame,
              let idx = game.players.firstIndex(where: { $0.playerName == player || $0.userID == player }) else { return }
        game.players[idx].scores.removeAll { Calendar.current.isDate($0.date, inSameDayAs: date) }
        game.players[idx].scores.append(DailyScore(date: date, score: score))
        game.players[idx].scores.sort { $0.date < $1.date }
        currentGame = game
        save()
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(Game.self, from: data) {
            currentGame = decoded
        }
    }

    func save() {
        if let game = currentGame,
           let data = try? JSONEncoder().encode(game) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Scorecard View

struct ScorecardView: View {
    @StateObject private var apiService = APIService.shared
    @State private var myScores: [Score] = []
    @State private var shareText = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var pendingScore: Int?
    @State private var pendingDate: Date?
    @State private var showOverwriteAlert = false
    @State private var selectedDate = Date()
    @State private var isLoading = false
    @State private var showUserSetup = false
    @State private var userHandle = ""
    
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    private func scoreString(_ score: Int) -> String {
        if score == 1 {
            return "⛳"
        } else if score <= 6 {
            return "\(score)"
        } else {
            return "X"
        }
    }
    
    private func loadScores() async {
        guard apiService.isLoggedIn else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            let startDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            let endDate = Date()
            
            myScores = try await apiService.getUserScores(
                startDate: formatter.string(from: startDate),
                endDate: formatter.string(from: endDate)
            )
        } catch {
            alertMessage = "Failed to load scores: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func formatPuzzleDate(_ puzzleDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: puzzleDate) {
            return shortDate(date)
        }
        return puzzleDate
    }
    
    private func submitScore() async {
        guard let (score, _) = parseNYTShareString(shareText) else {
            alertMessage = "Could not parse the Wordle share string. Please check your input."
            showingAlert = true
            return
        }
        
        guard apiService.isLoggedIn else {
            showUserSetup = true
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let puzzleDateString = formatter.string(from: selectedDate)
            
            let _ = try await apiService.submitScore(
                puzzleDate: puzzleDateString,
                status: .solved,
                guessesUsed: score,
                sourceText: shareText
            )
            
            shareText = ""
            alertMessage = "Score added for \(shortDate(selectedDate))!"
            showingAlert = true
            
            // Reload scores to show the new one
            await loadScores()
            
        } catch {
            alertMessage = "Failed to submit score: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func createUser() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let _ = try await apiService.createUser(handle: userHandle.trimmingCharacters(in: .whitespaces))
            showUserSetup = false
            
            // Load scores after successful user creation
            Task {
                await loadScores()
            }
            
        } catch {
            alertMessage = "Failed to create account: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // My Scores Display
            if !myScores.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("My Scores")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(myScores.sorted(by: { $0.puzzleDate < $1.puzzleDate }), id: \.id) { score in
                                VStack {
                                    Text(formatPuzzleDate(score.puzzleDate))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(scoreString(score.golfScore))
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(.green)
                                }
                                .frame(width: 60, height: 60)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                Divider()
            }
            
            // Date Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Date")
                    .font(.headline)
                    .padding(.horizontal)
                
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(.horizontal)
            }
            
            // Input Section
            VStack(spacing: 16) {
                Text("Paste your Wordle share string below:")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextEditor(text: $shareText)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)

                Button("Add Score") {
                    Task {
                        await submitScore()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(shareText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            
            Spacer()
        }
        .onAppear {
            if !apiService.isLoggedIn {
                showUserSetup = true
            } else {
                Task {
                    await loadScores()
                }
            }
        }
        .sheet(isPresented: $showUserSetup) {
            VStack(spacing: 24) {
                Text("Create Account")
                    .font(.title)
                
                Text("Enter a username to get started")
                    .foregroundColor(.secondary)
                
                TextField("Username", text: $userHandle)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                Button("Create Account") {
                    Task {
                        await createUser()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(userHandle.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                
                if isLoading {
                    ProgressView()
                }
            }
            .padding()
        }
        .alert("Info", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .navigationTitle("Scorecard")
        .navigationBarTitleDisplayMode(.inline)
    }
    
}

func parseNYTShareString(_ shareString: String) -> (score: Int, date: Date)? {
    let lines = shareString.components(separatedBy: .newlines).filter { !$0.isEmpty }
    guard let firstLine = lines.first else { return nil }
    
    // Parse "Wordle 1,513 2/6" format
    let components = firstLine.components(separatedBy: " ")
    guard components.count >= 3,
          components[0].lowercased() == "wordle",
          components[2].contains("/") else { return nil }
    
    // Extract score from "2/6" format - the number before the slash
    let scoreParts = components[2].components(separatedBy: "/")
    guard scoreParts.count == 2,
          let score = Int(scoreParts[0]) else { return nil }
    
    // Count emoji lines to verify the score
    let emojiLines = lines.filter { line in
        line.contains("🟨") || line.contains("🟩") || line.contains("⬜") || line.contains("⬛")
    }
    
    // Return the score from the share text (we'll use selectedDate from the UI)
    return (score: score, date: Date())
}
