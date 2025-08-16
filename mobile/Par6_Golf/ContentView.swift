//
//  ContentView.swift
//  Par6_Golf
//
//  Created by Cole Michael Riddlebarger on 6/4/25.
//

import SwiftUI
import Foundation

// MARK: - Profile View

struct ProfileView: View {
    @StateObject private var apiService = APIService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if apiService.isLoggedIn {
                    VStack(spacing: 16) {
                        Text("Par6 Golf")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.green)
                        
                        if let user = apiService.currentUser {
                            Text("@\(user.handle)")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Sign Out") {
                            apiService.logout()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("Par6 Golf")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.green)
                        
                        Text("Track your Wordle scores")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Please log in to continue")
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Profile")
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Main ContentView

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ScorecardView()
            }
            .tabItem {
                Image(systemName: "doc.text.fill")
                Text("Scorecard")
            }

            NavigationStack {
                TournamentView()
            }
            .tabItem {
                Image(systemName: "flag.fill")
                Text("Tournaments")
            }

            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }
        }
        .tint(.green)
    }
}


// MARK: - Scorecard View

struct ScorecardView: View {
    @StateObject private var apiService = APIService.shared
    @State private var myScores: [Score] = []
    @State private var shareText = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var selectedDate = Date()
    @State private var isLoading = false
    @State private var showUserSetup = false
    @State private var userHandle = ""
    @State private var showCalendar = false
    @State private var dateJustSelected = false
    @State private var loadTask: Task<Void, Never>?
    
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    private func scoreString(_ golfScore: Int) -> String {
        switch golfScore {
        case -3: return "⛳"    // Ace (1/6)
        case -2: return "-2"   // Eagle (2/6) 
        case -1: return "-1"   // Birdie (3/6)
        case 0: return "E"     // Par (4/6)
        case 1: return "+1"    // Bogey (5/6)
        case 2: return "+2"    // Double Bogey (6/6)
        case 4: return "+4"    // Penalty/DNF (X/6)
        default: return "+\(golfScore)"
        }
    }
    
    private func loadScores() async {
        guard apiService.isLoggedIn else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Check for cancellation
            try Task.checkCancellation()
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            let startDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            let endDate = Date()
            
            myScores = try await apiService.getUserScores(
                startDate: formatter.string(from: startDate),
                endDate: formatter.string(from: endDate)
            )
        } catch is CancellationError {
            print("[DEBUG] Load scores was cancelled")
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
    
    private func formatSelectedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
    }
    
    private func formatSelectedDateShort() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: selectedDate)
    }
    
    private func getScoreForSelectedDate() -> Score? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let selectedDateString = formatter.string(from: selectedDate)
        
        return myScores.first { $0.puzzleDate == selectedDateString }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func submitScore() async {
        guard let (score, _) = parseNYTShareString(shareText) else {
            alertMessage = "Could not parse the Wordle share string. Please check your input."
            showingAlert = true
            return
        }
        
        guard apiService.isLoggedIn else {
            alertMessage = "Please login first to submit scores."
            showingAlert = true
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let puzzleDateString = formatter.string(from: selectedDate)
            
            // Handle failed attempts (score 7) vs successful solves (1-6)
            let status: Status
            let guessesUsed: Int?
            
            if score == 7 {
                status = .dnf
                guessesUsed = nil
            } else {
                status = .solved
                guessesUsed = score
            }
            
            let _ = try await apiService.submitScore(
                puzzleDate: puzzleDateString,
                status: status,
                guessesUsed: guessesUsed,
                sourceText: shareText
            )
            
            let wasUpdate = getScoreForSelectedDate() != nil
            shareText = ""
            alertMessage = wasUpdate ? "Score updated for \(shortDate(selectedDate))!" : "Score added for \(shortDate(selectedDate))!"
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
            userHandle = "" // Clear the field for next time
            
            // Load scores after successful login/creation
            await loadScores()
            
        } catch {
            alertMessage = "Login failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Header
                    VStack(spacing: 8) {
                        Text("Par6 Golf")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.green)
                        Text("Track your Wordle scores")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if !apiService.isLoggedIn {
                            Button("Get Started") {
                                showUserSetup = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .padding(.top, 8)
                        } else if let user = apiService.currentUser {
                            Text("Welcome back, @\(user.handle)!")
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top)
                    
                    // My Scores Display
                    if !myScores.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("My Recent Scores")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(myScores.sorted(by: { $0.puzzleDate > $1.puzzleDate }).prefix(10), id: \.id) { score in
                                        VStack(spacing: 4) {
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
                                        .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Input Section (only show when logged in)
                    if apiService.isLoggedIn {
                        VStack(spacing: 24) {
                            // Date Selection Card
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Add Score for Date")
                                        .font(.headline)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                VStack(spacing: 12) {
                                    // Tappable date selector
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            showCalendar.toggle()
                                        }
                                    }) {
                                        HStack {
                                            Text("Selected Date:")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(formatSelectedDate())
                                                .font(.subheadline)
                                                .bold()
                                                .foregroundColor(.green)
                                            Image(systemName: showCalendar ? "chevron.up" : "chevron.down")
                                                .foregroundColor(.green)
                                                .font(.caption)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Show existing score if any
                                    if let existingScore = getScoreForSelectedDate() {
                                        HStack {
                                            Text("Current Score:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(scoreString(existingScore.golfScore))
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(.orange)
                                            Text("(will be updated)")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    
                                    // Collapsible calendar
                                    if showCalendar {
                                        VStack {
                                            DatePicker("Select Date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                                                .datePickerStyle(.graphical)
                                                .accentColor(.green)
                                                .onChange(of: selectedDate) { oldValue, newValue in
                                                    print("[DEBUG] Date changed from \(oldValue) to \(newValue)")
                                                    // Auto-collapse calendar and guide user to input
                                                    withAnimation(.easeInOut(duration: 0.3)) {
                                                        showCalendar = false
                                                        dateJustSelected = true
                                                    }
                                                    
                                                    // Reset the highlight after a few seconds
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                                        withAnimation(.easeOut(duration: 0.5)) {
                                                            dateJustSelected = false
                                                        }
                                                    }
                                                }
                                        }
                                        .transition(.opacity.combined(with: .scale))
                                        .allowsHitTesting(true)
                                    }
                                }
                                .padding()
                                .background(Color.green.opacity(0.05))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            
                            // Score Input Section
                            VStack(spacing: 16) {
                                VStack(spacing: 8) {
                                    if dateJustSelected {
                                        Text("Perfect! Now paste your Wordle score:")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.green)
                                            .multilineTextAlignment(.center)
                                            .transition(.opacity.combined(with: .scale))
                                        
                                        Text("For \(formatSelectedDate())")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .transition(.opacity)
                                    } else {
                                        Text("Paste your Wordle share string for \(formatSelectedDate()):")
                                            .font(.subheadline)
                                            .multilineTextAlignment(.center)
                                            .transition(.opacity)
                                    }
                                }
                                .padding(.horizontal)
                                .onTapGesture {
                                    hideKeyboard()
                                }

                                TextEditor(text: $shareText)
                                    .frame(height: 120)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                dateJustSelected ? Color.green.opacity(0.8) :
                                                shareText.isEmpty ? Color.gray.opacity(0.3) : Color.green.opacity(0.5), 
                                                lineWidth: dateJustSelected ? 3 : (shareText.isEmpty ? 1 : 2)
                                            )
                                            .animation(.easeInOut(duration: 0.3), value: dateJustSelected)
                                    )
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(dateJustSelected ? Color.green.opacity(0.05) : Color.clear)
                                            .animation(.easeInOut(duration: 0.3), value: dateJustSelected)
                                    )
                                    .onChange(of: shareText) { oldValue, newValue in
                                        // Clear highlight when user starts typing
                                        if !newValue.isEmpty && dateJustSelected {
                                            withAnimation(.easeOut(duration: 0.3)) {
                                                dateJustSelected = false
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .toolbar {
                                        ToolbarItemGroup(placement: .keyboard) {
                                            Spacer()
                                            Button("Done") {
                                                hideKeyboard()
                                            }
                                        }
                                    }

                                Button(action: {
                                    Task {
                                        await submitScore()
                                    }
                                }) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .foregroundColor(.white)
                                        } else {
                                            Image(systemName: "plus.circle.fill")
                                        }
                                        Text(getScoreForSelectedDate() != nil ? "Update Score for \(formatSelectedDateShort())" : "Add Score for \(formatSelectedDateShort())")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(shareText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading ? Color.gray : Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(shareText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 20)
                    } else {
                        // Show a message when not logged in
                        VStack(spacing: 16) {
                            Image(systemName: "golf.flag")
                                .font(.system(size: 48))
                                .foregroundColor(.green.opacity(0.6))
                            
                            Text("Ready to start?")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Tap 'Get Started' above to begin tracking your daily Wordle scores!")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .refreshable {
            if apiService.isLoggedIn {
                loadTask?.cancel()
                loadTask = Task {
                    await loadScores()
                }
                await loadTask?.value
            }
        }
        .onAppear {
            if apiService.isLoggedIn {
                loadTask?.cancel()
                loadTask = Task {
                    await loadScores()
                }
            }
        }
        .sheet(isPresented: $showUserSetup) {
            NavigationStack {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Text("Par6 Golf")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.green)
                        
                        Text("Just enter any username to continue. We'll log you in or create your account automatically.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 20) {
                        TextField("Username", text: $userHandle)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button(action: {
                            Task {
                                await createUser()
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                Text("Continue")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(userHandle.trimmingCharacters(in: .whitespaces).isEmpty || isLoading ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(userHandle.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    }
                    
                    Spacer()
                }
                .padding()
                .navigationBarHidden(true)
            }
            .interactiveDismissDisabled()
        }
        .alert("Info", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
}

// MARK: - Tournament View

struct TournamentView: View {
    @StateObject private var apiService = APIService.shared
    @State private var tournaments: [TournamentSummary] = []
    @State private var selectedTournament: TournamentSummary?
    @State private var showingCreateTournament = false
    @State private var showingJoinTournament = false
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var loadTask: Task<Void, Never>?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Golf Tournaments")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.green)
                    Text("18-day Wordle competitions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                if !apiService.isLoggedIn {
                    VStack(spacing: 16) {
                        Image(systemName: "flag.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.green.opacity(0.6))
                        Text("Login to join tournaments")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                } else {
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button("Create Tournament") {
                            showingCreateTournament = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        
                        Button("Join Tournament") {
                            showingJoinTournament = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }
                    .padding(.horizontal)
                    
                    // Tournaments List
                    if tournaments.isEmpty && !isLoading {
                        VStack(spacing: 16) {
                            Image(systemName: "flag.2.crossed")
                                .font(.system(size: 32))
                                .foregroundColor(.green.opacity(0.6))
                            Text("No tournaments yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Create your first tournament or join one with friends!")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(tournaments) { tournament in
                                TournamentCard(tournament: tournament) {
                                    selectedTournament = tournament
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                if isLoading {
                    ProgressView()
                        .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .refreshable {
            if apiService.isLoggedIn {
                loadTask?.cancel()
                loadTask = Task {
                    await loadTournaments()
                }
                await loadTask?.value
            }
        }
        .onAppear {
            if apiService.isLoggedIn {
                loadTask?.cancel()
                loadTask = Task {
                    await loadTournaments()
                }
            }
        }
        .sheet(item: $selectedTournament) { tournament in
            TournamentDetailView(tournament: tournament)
        }
        .sheet(isPresented: $showingCreateTournament) {
            CreateTournamentView { 
                loadTask?.cancel()
                loadTask = Task { await loadTournaments() }
            }
        }
        .sheet(isPresented: $showingJoinTournament) {
            JoinTournamentView {
                loadTask?.cancel()
                loadTask = Task { await loadTournaments() }
            }
        }
        .alert("Tournament", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadTournaments() async {
        print("[DEBUG] loadTournaments called")
        
        isLoading = true
        defer { 
            print("[DEBUG] Setting isLoading to false")
            isLoading = false 
        }
        
        do {
            // Check for cancellation
            try Task.checkCancellation()
            
            print("[DEBUG] Loading tournaments from API...")
            tournaments = try await apiService.getTournaments()
            print("[DEBUG] Loaded \(tournaments.count) tournaments")
        } catch is CancellationError {
            print("[DEBUG] Load tournaments was cancelled")
        } catch {
            print("[DEBUG] Failed to load tournaments: \(error)")
            alertMessage = "Failed to load tournaments: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// MARK: - Tournament Card

struct TournamentCard: View {
    let tournament: TournamentSummary
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tournament.tournament.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("\(tournament.tournament.durationDays)-Day Tournament (Par \(tournament.tournament.durationDays * 4))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    if tournament.userParticipating {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Mini leaderboard preview
                if !tournament.standings.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(tournament.standings.prefix(3)) { standing in
                            HStack {
                                Text("#\(standing.position)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .leading)
                                
                                Text(standing.handle)
                                    .font(.caption)
                                    .foregroundColor(standing.isCurrentUser ? .green : .primary)
                                
                                Spacer()
                                
                                Text("\(standing.totalScore)")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.green)
                                
                                Text("(\(standing.completedDays)/\(tournament.tournament.durationDays))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                HStack {
                    Text("Starts: \(formatDate(tournament.tournament.startDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(tournament.standings.count) players")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Supporting Tournament Views

struct TournamentDetailView: View {
    let tournament: TournamentSummary
    @StateObject private var apiService = APIService.shared
    @State private var tournamentDetails: TournamentSummary?
    @State private var isLoading = false
    @State private var showingShare = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Tournament Header
                    VStack(spacing: 12) {
                        Text(tournament.tournament.name)
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.green)
                        
                        Text("\(tournament.tournament.durationDays)-Day Wordle Golf Tournament (Par \(tournament.tournament.durationDays * 4))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            VStack {
                                Text("Start")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatDate(tournament.tournament.startDate))
                                    .font(.subheadline)
                                    .bold()
                            }
                            
                            Text("—")
                                .foregroundColor(.secondary)
                            
                            VStack {
                                Text("End")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatDate(tournament.tournament.endDate))
                                    .font(.subheadline)
                                    .bold()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Leaderboard
                    if !tournament.standings.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Leaderboard")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVStack(spacing: 8) {
                                ForEach(tournament.standings) { standing in
                                    HStack {
                                        Text("#\(standing.position)")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                            .frame(width: 30, alignment: .leading)
                                        
                                        Text(standing.handle)
                                            .font(.headline)
                                            .foregroundColor(standing.isCurrentUser ? .green : .primary)
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing) {
                                            Text("\(standing.totalScore)")
                                                .font(.headline)
                                                .bold()
                                                .foregroundColor(.green)
                                            Text("\(standing.completedDays)/\(tournament.tournament.durationDays))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding()
                                    .background(standing.isCurrentUser ? Color.green.opacity(0.1) : Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Share Button
                    Button("Share Tournament") {
                        showingShare = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await loadTournamentDetails()
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            ShareTournamentView(tournament: tournament.tournament)
        }
    }
    
    private func loadTournamentDetails() async {
        // Prevent multiple simultaneous loads
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            tournamentDetails = try await apiService.getTournamentDetails(tournamentId: tournament.tournament.id)
        } catch {
            print("Failed to load tournament details: \(error)")
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return dateString
    }
}

struct ShareTournamentView: View {
    let tournament: Tournament
    let onComplete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    init(tournament: Tournament, onComplete: (() -> Void)? = nil) {
        self.tournament = tournament
        self.onComplete = onComplete
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Share Tournament")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.green)
                    
                    Text("Share this tournament ID with friends so they can join your competition!")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 16) {
                    Text("Tournament ID")
                        .font(.headline)
                    
                    Text(tournament.id)
                        .font(.title2)
                        .bold()
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                }
                
                Button("Copy Tournament ID") {
                    UIPasteboard.general.string = tournament.id
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { 
                        dismiss()
                        onComplete?()
                    }
                }
            }
        }
    }
}

struct CreateTournamentView: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = APIService.shared
    @State private var tournamentName = ""
    @State private var startDate = Date()
    @State private var durationDays = 18
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var createdTournament: Tournament?
    @State private var showingShare = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Create Tournament")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.green)
                    
                    Text("Create a Wordle golf tournament to compete with friends!")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 16) {
                    TextField("Tournament Name", text: $tournamentName)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tournament Length")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Duration", selection: $durationDays) {
                            Text("9 Days (Par 36)").tag(9)
                            Text("18 Days (Par 72)").tag(18)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start Date")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        DatePicker("", selection: $startDate, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                }
                .padding(.horizontal)
                
                Button(action: {
                    Task {
                        await createTournament()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "flag.fill")
                        }
                        Text("Create Tournament")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tournamentName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(tournamentName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            if let tournament = createdTournament {
                ShareTournamentView(tournament: tournament) {
                    // When share is complete, dismiss the entire create tournament flow
                    dismiss()
                    onComplete()
                }
            }
        }
        .alert("Tournament", isPresented: $showingAlert) {
            Button("OK") {
                if createdTournament != nil {
                    showingShare = true
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func createTournament() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let startDateString = formatter.string(from: startDate)
            
            let tournament = try await apiService.createTournament(
                name: tournamentName.trimmingCharacters(in: .whitespaces),
                startDate: startDateString,
                durationDays: durationDays
            )
            
            createdTournament = tournament
            alertMessage = "Tournament '\(tournament.name)' created successfully! Share the tournament ID with friends."
            showingAlert = true
            onComplete()
            
        } catch {
            alertMessage = "Failed to create tournament: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct JoinTournamentView: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = APIService.shared
    @State private var tournamentId = ""
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Join Tournament")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.green)
                    
                    Text("Enter the tournament ID shared by your friend to join their 18-day Wordle golf competition!")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 16) {
                    TextField("Tournament ID", text: $tournamentId)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.horizontal)
                    
                    Text("The tournament ID is a unique code your friend got when creating the tournament.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    Task {
                        await joinTournament()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text("Join Tournament")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tournamentId.trimmingCharacters(in: .whitespaces).isEmpty || isLoading ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(tournamentId.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .alert("Tournament", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.contains("successfully") {
                    dismiss()
                    onComplete()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func joinTournament() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let tournament = try await apiService.joinTournament(
                tournamentId: tournamentId.trimmingCharacters(in: .whitespaces)
            )
            
            alertMessage = "Successfully joined '\(tournament.name)'! Start playing Wordle and submit your scores to compete."
            showingAlert = true
            
        } catch {
            alertMessage = "Failed to join tournament: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

func parseNYTShareString(_ shareString: String) -> (score: Int, date: Date)? {
    let lines = shareString.components(separatedBy: .newlines).filter { !$0.isEmpty }
    guard let firstLine = lines.first else { return nil }
    
    // Parse "Wordle 1,XXX Y/6" format (where Y can be 1-6 or X for failed)
    let components = firstLine.components(separatedBy: " ")
    guard components.count >= 3,
          components[0].lowercased() == "wordle",
          components[2].contains("/") else { return nil }
    
    // Extract score from "2/6" or "X/6" format
    let scoreParts = components[2].components(separatedBy: "/")
    guard scoreParts.count == 2,
          scoreParts[1] == "6" else { return nil } // Ensure it's out of 6
    
    let scoreString = scoreParts[0].uppercased()
    let score: Int
    
    // Handle both numeric scores (1-6) and X (failed)
    if scoreString == "X" {
        score = 7 // Use 7 to represent failed/DNF
    } else if let numericScore = Int(scoreString), numericScore >= 1 && numericScore <= 6 {
        score = numericScore
    } else {
        return nil // Invalid score format
    }
    
    // Count emoji lines to verify the score matches
    let emojiLines = lines.filter { line in
        line.contains("🟨") || line.contains("🟩") || line.contains("⬜") || line.contains("⬛")
    }
    
    // For successful solves (1-6), emoji lines should match the score
    // For failed attempts (X), there should be exactly 6 emoji lines
    let expectedEmojiLines = (score == 7) ? 6 : score
    if emojiLines.count != expectedEmojiLines {
        return nil // Mismatch between declared score and actual emoji lines
    }
    
    // Return the score from the share text (we'll use selectedDate from the UI)
    return (score: score, date: Date())
}
