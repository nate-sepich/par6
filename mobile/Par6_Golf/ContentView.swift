//
//  ContentView.swift
//  Par6_Golf
//
//  Created by Cole Michael Riddlebarger on 6/4/25.
//

import SwiftUI
import Foundation
import Combine

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
                            .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
                        
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
                            .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
                        
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
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @State private var showingDeepLinkJoin = false
    @State private var deepLinkTournamentCode: String = ""
    
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
        .onReceive(deepLinkManager.$pendingTournamentJoin) { tournamentCode in
            if let code = tournamentCode {
                deepLinkTournamentCode = code
                showingDeepLinkJoin = true
            }
        }
        .alert("Join Tournament", isPresented: $showingDeepLinkJoin) {
            Button("Join") {
                Task {
                    await joinTournamentFromDeepLink()
                }
            }
            Button("Cancel", role: .cancel) {
                deepLinkManager.clearPendingJoin()
            }
        } message: {
            Text("Would you like to join the tournament with code \(deepLinkTournamentCode)?")
        }
    }
    
    private func joinTournamentFromDeepLink() async {
        guard !deepLinkTournamentCode.isEmpty else { return }
        
        do {
            let apiService = APIService.shared
            let tournament = try await apiService.joinTournament(tournamentId: deepLinkTournamentCode)
            
            // Clear the deep link
            await MainActor.run {
                deepLinkManager.clearPendingJoin()
                print("[DEEP LINK DEBUG] Successfully joined tournament: \(tournament.name)")
            }
            
        } catch {
            // Handle error
            await MainActor.run {
                deepLinkManager.clearPendingJoin()
                print("[DEEP LINK DEBUG] Failed to join tournament: \(error.localizedDescription)")
            }
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
                            .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
                        Text("Track your Wordle scores")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if !apiService.isLoggedIn {
                            Button("Get Started") {
                                showUserSetup = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.224, green: 0.573, blue: 0.318))
                            .padding(.top, 8)
                        } else if let user = apiService.currentUser {
                            Text("Welcome back, @\(user.handle)!")
                                .font(.subheadline)
                                .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
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
                                                .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
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
                                                .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
                                            Image(systemName: showCalendar ? "chevron.up" : "chevron.down")
                                                .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
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
                                            .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
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
                            Image(systemName: "flag.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Color(red: 0.318, green: 0.651, blue: 0.408).opacity(0.6))
                            
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
                            .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
                        
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
    @State private var showingPublicTournaments = false
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
                        .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
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
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            Button("Create Tournament") {
                                showingCreateTournament = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.224, green: 0.573, blue: 0.318))
                            
                            Button("Join Tournament") {
                                showingJoinTournament = true
                            }
                            .buttonStyle(.bordered)
                            .tint(Color(red: 0.224, green: 0.573, blue: 0.318))
                        }
                        
                        Button("Browse Public Tournaments") {
                            showingPublicTournaments = true
                        }
                        .buttonStyle(.bordered)
                        .tint(Color(red: 0.329, green: 0.549, blue: 0.753))
                    }
                    .padding(.horizontal)
                    
                    // Tournaments List
                    if tournaments.isEmpty && !isLoading {
                        VStack(spacing: 16) {
                            Image(systemName: "flag.2.crossed")
                                .font(.system(size: 32))
                                .foregroundColor(Color(red: 0.318, green: 0.651, blue: 0.408).opacity(0.6))
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
                                .contextMenu {
                                    if let currentUser = apiService.currentUser, 
                                       tournament.tournament.createdBy == currentUser.userId {
                                        Button("Delete Tournament", role: .destructive) {
                                            deleteTournament(tournament.tournament)
                                        }
                                    }
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
        .sheet(isPresented: $showingPublicTournaments) {
            PublicTournamentsView {
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
    
    private func deleteTournament(_ tournament: Tournament) {
        Task {
            do {
                try await apiService.deleteTournament(tournamentId: tournament.id)
                await loadTournaments() // Refresh the list
            } catch {
                alertMessage = "Failed to delete tournament: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

// MARK: - Tournament Card

struct TournamentCard: View {
    let tournament: TournamentSummary
    let onTap: () -> Void
    
    private var isPublic: Bool {
        tournament.tournament.tournamentType == "public"
    }
    
    private var statusColor: Color {
        if !tournament.tournament.isActive { return Color(red: 0.945, green: 0.588, blue: 0.275) }
        return tournament.userParticipating ? Color(red: 0.224, green: 0.573, blue: 0.318) : (isPublic ? Color(red: 0.329, green: 0.549, blue: 0.753) : Color(red: 0.224, green: 0.573, blue: 0.318))
    }
    
    private var cardBackground: Color {
        if !tournament.tournament.isActive { 
            return Color(.systemGray5) 
        }
        return isPublic ? Color(.systemBlue).opacity(0.06) : Color(.systemGray6)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Main content
                VStack(alignment: .leading, spacing: 16) {
                    // Header section
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(tournament.tournament.name)
                                    .font(.system(.title3, design: .rounded, weight: .semibold))
                                    .foregroundColor(tournament.tournament.isActive ? .primary : .secondary)
                                    .lineLimit(2)
                                
                                if !tournament.tournament.isActive {
                                    Image(systemName: "flag.checkered")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                
                                Spacer(minLength: 0)
                            }
                            
                            // Tournament type and status
                            HStack(spacing: 8) {
                                Label {
                                    Text(isPublic ? "Public" : "Private")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .fixedSize()
                                } icon: {
                                    Image(systemName: isPublic ? "globe" : "lock.fill")
                                        .font(.caption2)
                                }
                                .foregroundColor(isPublic ? Color(red: 0.329, green: 0.549, blue: 0.753) : Color(red: 0.224, green: 0.573, blue: 0.318))
                                
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 3, height: 3)
                                
                                Text("\(tournament.tournament.durationDays) days")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 3, height: 3)
                                
                                Text("Par \(tournament.tournament.durationDays * 4)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Status icon
                        VStack(spacing: 4) {
                            Group {
                                if tournament.userParticipating {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(statusColor)
                                } else if tournament.tournament.isActive {
                                    Image(systemName: isPublic ? "globe.badge.chevron.backward" : "plus.circle")
                                        .foregroundColor(statusColor)
                                } else {
                                    Image(systemName: "flag.checkered.circle")
                                        .foregroundColor(.orange)
                                }
                            }
                            .font(.title2)
                            .imageScale(.medium)
                            
                            if tournament.tournament.isActive {
                                Text(tournament.userParticipating ? "Joined" : "Join")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(statusColor)
                            } else {
                                Text("Ended")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    // Leaderboard preview
                    if !tournament.standings.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Leaderboard")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            VStack(spacing: 6) {
                                ForEach(tournament.standings.prefix(3)) { standing in
                                    HStack(spacing: 10) {
                                        // Position badge
                                        Text("\(standing.position)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .frame(width: 20, height: 20)
                                            .background(
                                                Circle()
                                                    .fill(standing.position <= 3 ? statusColor : Color(.systemGray))
                                            )
                                        
                                        Text(standing.handle)
                                            .font(.subheadline)
                                            .fontWeight(standing.isCurrentUser ? .semibold : .regular)
                                            .foregroundColor(standing.isCurrentUser ? statusColor : .primary)
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(standing.totalScore > 0 ? "+" : "")\(standing.totalScore)")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(standing.totalScore <= 0 ? Color(red: 0.224, green: 0.573, blue: 0.318) : Color(red: 0.827, green: 0.294, blue: 0.302))
                                            
                                            Text("\(standing.completedDays)/\(tournament.tournament.durationDays)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                if tournament.standings.count > 3 {
                                    HStack {
                                        Image(systemName: "ellipsis")
                                            .foregroundColor(.secondary)
                                        Text("and \(tournament.standings.count - 3) more")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.leading, 30)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                
                // Footer section
                Divider()
                
                HStack {
                    Label {
                        Text(formatDate(tournament.tournament.startDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Label {
                        Text("\(tournament.standings.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "person.2")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isPublic ? Color(.systemBlue).opacity(0.2) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            .opacity(tournament.tournament.isActive ? 1.0 : 0.85)
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
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @Environment(\.dismiss) private var dismiss
    
    private var currentTournament: TournamentSummary {
        tournamentDetails ?? tournament
    }
    
    private var isPublic: Bool {
        currentTournament.tournament.tournamentType == "public"
    }
    
    private var statusColor: Color {
        currentTournament.tournament.isActive ? Color(red: 0.224, green: 0.573, blue: 0.318) : Color(red: 0.945, green: 0.588, blue: 0.275)
    }
    
    private var statusIcon: String {
        currentTournament.tournament.isActive ? "play.circle.fill" : "trophy.fill"
    }
    
    private var statusText: String {
        currentTournament.tournament.isActive ? "Active" : "Completed"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Hero Header Section
                    VStack(spacing: 0) {
                        // Tournament name and status
                        VStack(spacing: 16) {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: isPublic ? "globe.americas.fill" : "lock.fill")
                                        .font(.title3)
                                        .foregroundStyle(LinearGradient(
                                            colors: isPublic ? [Color(red: 0.329, green: 0.549, blue: 0.753), .cyan] : [Color(red: 0.224, green: 0.573, blue: 0.318), Color(red: 0.533, green: 0.804, blue: 0.643)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                    
                                    Text(isPublic ? "Public Tournament" : "Private Tournament")
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .foregroundColor(isPublic ? Color(red: 0.329, green: 0.549, blue: 0.753) : Color(red: 0.224, green: 0.573, blue: 0.318))
                                        .fixedSize()
                                        .textCase(.uppercase)
                                }
                                
                                Text(currentTournament.tournament.name)
                                    .font(.system(.title, design: .rounded, weight: .bold))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Status badge
                            HStack(spacing: 8) {
                                Image(systemName: statusIcon)
                                    .font(.system(.body, weight: .semibold))
                                    .foregroundColor(statusColor)
                                
                                Text(statusText)
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .foregroundColor(statusColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(statusColor.opacity(0.12))
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                        .background(
                            LinearGradient(
                                colors: isPublic ? 
                                    [Color(red: 0.329, green: 0.549, blue: 0.753).opacity(0.03), Color.cyan.opacity(0.01)] :
                                    [Color(red: 0.224, green: 0.573, blue: 0.318).opacity(0.03), Color(red: 0.533, green: 0.804, blue: 0.643).opacity(0.01)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        
                        // Tournament Info Cards
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            InfoCard(
                                title: "Duration",
                                value: "\(currentTournament.tournament.durationDays) Days",
                                icon: "calendar",
                                color: Color(red: 0.329, green: 0.549, blue: 0.753)
                            )
                            
                            InfoCard(
                                title: "Par Score",
                                value: "\(currentTournament.tournament.durationDays * 4)",
                                icon: "target",
                                color: Color(red: 0.224, green: 0.573, blue: 0.318)
                            )
                            
                            InfoCard(
                                title: "Players",
                                value: "\(currentTournament.standings.count)",
                                icon: "person.2.fill",
                                color: Color(red: 0.945, green: 0.588, blue: 0.275)
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 20)
                    
                    // Tournament Dates
                    DateRangeCard(
                        startDate: currentTournament.tournament.startDate,
                        endDate: currentTournament.tournament.endDate
                    )
                    .padding(.horizontal, 20)
                    
                    // Leaderboard Section
                    if !currentTournament.standings.isEmpty {
                        LeaderboardSection(
                            standings: currentTournament.standings,
                            isActive: currentTournament.tournament.isActive,
                            tournamentName: currentTournament.tournament.name
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        // Join Tournament Button (for non-participants)
                        if !currentTournament.userParticipating && currentTournament.tournament.isActive {
                            Button(action: { 
                                Task { await joinTournamentFromDetail() }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(.body, weight: .semibold))
                                    
                                    Text("Join Tournament")
                                        .font(.system(.body, design: .rounded, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(LinearGradient(
                                            colors: [Color(red: 0.224, green: 0.573, blue: 0.318), Color(red: 0.533, green: 0.804, blue: 0.643)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                )
                                .foregroundColor(.white)
                                .shadow(color: Color(red: 0.224, green: 0.573, blue: 0.318).opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        }
                        
                        // Share Button
                        Button(action: { showingShare = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(.body, weight: .semibold))
                                
                                Text("Share Tournament")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                            .foregroundColor(.white)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        // Leave Tournament Button
                        if currentTournament.userParticipating && 
                           currentTournament.tournament.createdBy != apiService.currentUser?.userId &&
                           currentTournament.tournament.isActive {
                            Button(action: { 
                                Task { await leaveTournament() }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "minus.circle")
                                        .font(.system(.body, weight: .semibold))
                                    
                                    Text("Leave Tournament")
                                        .font(.system(.body, design: .rounded, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.red.opacity(0.05))
                                        )
                                )
                                .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 32)
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await loadTournamentDetails()
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            ShareTournamentView(tournament: currentTournament.tournament)
        }
        .alert("Tournament", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
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
    
    private func joinTournamentFromDetail() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let joinedTournament = try await apiService.joinTournament(tournamentId: tournament.tournament.id)
            alertMessage = "Successfully joined '\(joinedTournament.name)'! Start playing Wordle to compete."
            showingAlert = true
            
            // Reload tournament details to update the UI
            await loadTournamentDetails()
            
        } catch {
            alertMessage = "Failed to join tournament: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func leaveTournament() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await apiService.leaveTournament(tournamentId: tournament.tournament.id)
            alertMessage = "Successfully left the tournament."
            showingAlert = true
            
            // Dismiss the detail view after leaving
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
            
        } catch {
            alertMessage = "Failed to leave tournament: \(error.localizedDescription)"
            showingAlert = true
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

// MARK: - Tournament Detail Supporting Views

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(.title3, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.08))
        )
    }
}

struct DateRangeCard: View {
    let startDate: String
    let endDate: String
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text("Tournament Schedule")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Starts")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(formatDateDisplay(startDate))
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Image(systemName: "arrow.right")
                    .font(.system(.body, weight: .medium))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ends")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(formatDateDisplay(endDate))
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
    }
    
    private func formatDateDisplay(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            if Calendar.current.isDateInToday(date) {
                return "Today"
            } else if Calendar.current.isDateInTomorrow(date) {
                return "Tomorrow"
            } else {
                formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: date)
            }
        }
        return dateString
    }
}

struct LeaderboardSection: View {
    let standings: [TournamentStanding]
    let isActive: Bool
    let tournamentName: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isActive ? "Current Leaderboard" : "Final Results")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if !isActive && !standings.isEmpty {
                        Text("🏆 Champion: \(standings.first?.handle ?? "Unknown")")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                if !standings.isEmpty {
                    Text("\(standings.count) players")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                }
            }
            
            // Standings List
            LazyVStack(spacing: 8) {
                ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                    LeaderboardRow(
                        standing: standing,
                        rank: index + 1,
                        isChampion: !isActive && index == 0,
                        showTrophy: !isActive && index < 3
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
    }
}

struct LeaderboardRow: View {
    let standing: TournamentStanding
    let rank: Int
    let isChampion: Bool
    let showTrophy: Bool
    
    private var rankColor: Color {
        if isChampion { return .orange }
        if rank == 2 { return .gray }
        if rank == 3 { return .brown }
        return .secondary
    }
    
    private var rankIcon: String {
        if isChampion { return "crown.fill" }
        if rank == 2 { return "medal.fill" }
        if rank == 3 { return "medal.fill" }
        return ""
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank indicator
            HStack(spacing: 6) {
                if showTrophy && !rankIcon.isEmpty {
                    Image(systemName: rankIcon)
                        .font(.system(.body, weight: .semibold))
                        .foregroundColor(rankColor)
                }
                
                Text("#\(rank)")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundColor(rankColor)
                    .frame(minWidth: 20, alignment: .leading)
            }
            
            // Player info
            VStack(alignment: .leading, spacing: 2) {
                Text(standing.handle)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(standing.isCurrentUser ? .blue : .primary)
                
                Text("\(standing.completedDays) rounds played")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text(standing.totalScore >= 0 ? "+\(standing.totalScore)" : "\(standing.totalScore)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(standing.totalScore <= 0 ? .green : .primary)
                
                if isChampion {
                    Text("CHAMPION")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundColor(.orange)
                        .textCase(.uppercase)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(standing.isCurrentUser ? 
                      AnyShapeStyle(LinearGradient(colors: [Color(red: 0.329, green: 0.549, blue: 0.753).opacity(0.06), Color.cyan.opacity(0.03)], startPoint: .leading, endPoint: .trailing)) :
                      AnyShapeStyle(Color(.systemGray6)))
                .stroke(standing.isCurrentUser ? Color.blue.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}

struct ShareTournamentView: View {
    let tournament: Tournament
    let onComplete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var copiedToClipboard = false
    @State private var hapticFeedback = false
    
    init(tournament: Tournament, onComplete: (() -> Void)? = nil) {
        self.tournament = tournament
        self.onComplete = onComplete
    }
    
    private var isPublic: Bool {
        tournament.tournamentType == "public"
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
    
    private var shareMessage: String {
        let privacy = isPublic ? "Public" : "Private"
        let inviteText = isPublic ? 
            "Join this public tournament - anyone can participate!" :
            "You're invited to join my private Wordle golf tournament!"
        
        let joinCode = tournament.id.prefix(8).uppercased()
        
        return isPublic ? """
        🏌️ \(inviteText)
        
        📛 \(tournament.name)
        🎯 \(privacy) • \(tournament.durationDays) days • Par \(tournament.durationDays * 4)
        📅 \(formatDate(tournament.startDate)) - \(formatDate(tournament.endDate))
        
        🔍 Search for: \(tournament.name)
        
        📱 Download Par6 Golf to compete!
        """ : """
        🏌️ \(inviteText)
        
        📛 \(tournament.name)
        🎯 \(privacy) • \(tournament.durationDays) days • Par \(tournament.durationDays * 4)
        📅 \(formatDate(tournament.startDate)) - \(formatDate(tournament.endDate))
        
        🔑 Join Code:
        
        \(joinCode)
        
        📋 Long-press the code above to copy, then open Par6 Golf → Join Tournament and paste
        
        📱 Download Par6 Golf to compete!
        """
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header section
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.green.opacity(0.15), .mint.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: isPublic ? "globe.americas.fill" : "paperplane.fill")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        }
                        
                        VStack(spacing: 8) {
                            Text("Share Tournament")
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Invite players to join your competition")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Tournament info card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(tournament.name)
                                    .font(.system(.headline, design: .rounded, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("\(isPublic ? "Public" : "Private") • \(tournament.durationDays) Days • Par \(tournament.durationDays * 4)")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .fixedSize()
                            }
                            
                            Spacer()
                            
                            Image(systemName: isPublic ? "globe.fill" : "lock.fill")
                                .font(.title2)
                                .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.224, green: 0.573, blue: 0.318).opacity(0.06))
                                .stroke(Color(red: 0.224, green: 0.573, blue: 0.318).opacity(0.2), lineWidth: 1)
                        )
                        
                        // Share options
                        VStack(spacing: 16) {
                            if isPublic {
                                // Public tournament - share name for search
                                ShareOptionCard(
                                    icon: "magnifyingglass",
                                    title: "Tournament Name",
                                    subtitle: "Others can search for this name",
                                    value: tournament.name,
                                    copyValue: tournament.name,
                                    copiedToClipboard: $copiedToClipboard
                                )
                            } else {
                                // Private tournament - share ID
                                ShareOptionCard(
                                    icon: "key.fill",
                                    title: "Join Code",
                                    subtitle: "8-character code for easy joining",
                                    value: tournament.id.prefix(8).uppercased(),
                                    copyValue: tournament.id.prefix(8).uppercased(),
                                    copiedToClipboard: $copiedToClipboard
                                )
                            }
                        }
                    }
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        // Native share button
                        Button(action: { showingShareSheet = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(.body, weight: .semibold))
                                
                                Text("Share Tournament")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient(
                                        colors: [Color(red: 0.224, green: 0.573, blue: 0.318), Color(red: 0.533, green: 0.804, blue: 0.643)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                            .foregroundColor(.white)
                            .shadow(color: Color(red: 0.224, green: 0.573, blue: 0.318).opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        // Quick copy button
                        Button(action: copyTournamentInfo) {
                            HStack(spacing: 12) {
                                Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.clipboard")
                                    .font(.system(.body, weight: .semibold))
                                
                                Text(copiedToClipboard ? "Copied!" : "Copy Info")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(red: 0.224, green: 0.573, blue: 0.318).opacity(0.3), lineWidth: 1.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(red: 0.224, green: 0.573, blue: 0.318).opacity(0.05))
                                    )
                            )
                            .foregroundColor(copiedToClipboard ? Color(red: 0.224, green: 0.573, blue: 0.318) : .primary)
                        }
                        .animation(.easeInOut(duration: 0.2), value: copiedToClipboard)
                    }
                    
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { 
                        dismiss()
                        onComplete?()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [shareMessage])
            }
        }
    }
    
    private func copyTournamentInfo() {
        UIPasteboard.general.string = shareMessage
        copiedToClipboard = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Reset copied state after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            copiedToClipboard = false
        }
    }
}

// Supporting share view components
struct ShareOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let value: String
    let copyValue: String
    @Binding var copiedToClipboard: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(value)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
                
                Button(action: {
                    UIPasteboard.general.string = copyValue
                    copiedToClipboard = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedToClipboard = false
                    }
                }) {
                    Text(copiedToClipboard ? "Copied!" : "Copy")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
                        .textCase(.uppercase)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct CreateTournamentView: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = APIService.shared
    @State private var tournamentName = ""
    @State private var startDate = Date()
    @State private var durationDays = 18
    @State private var isPublic = false
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var createdTournament: Tournament?
    @State private var showingShare = false
    
    private var createTournamentButtonBackground: AnyShapeStyle {
        let isDisabled = tournamentName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading
        
        if isDisabled {
            return AnyShapeStyle(Color(.systemGray4))
        } else {
            let colors = isPublic ? [Color(red: 0.329, green: 0.549, blue: 0.753), Color.cyan] : [Color(red: 0.224, green: 0.573, blue: 0.318), Color(red: 0.533, green: 0.804, blue: 0.643)]
            return AnyShapeStyle(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header section
                    VStack(spacing: 16) {
                        Image(systemName: "flag.2.crossed.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(colors: [Color(red: 0.224, green: 0.573, blue: 0.318), Color(red: 0.318, green: 0.651, blue: 0.408)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .symbolEffect(.pulse.wholeSymbol)
                        
                        Text("Create Tournament")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .multilineTextAlignment(.center)
                        
                        Text("Start a Wordle golf competition and invite players to compete!")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    // Form sections
                    VStack(spacing: 24) {
                        // Tournament name section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Tournament Name", systemImage: "textformat.abc")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Enter a memorable name...", text: $tournamentName)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.words)
                                .submitLabel(.next)
                        }
                        .padding(.horizontal)
                        
                        // Duration section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Tournament Length", systemImage: "calendar.badge.clock")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 12) {
                                ForEach([9, 18], id: \.self) { days in
                                    Button(action: { durationDays = days }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("\(days) Days")
                                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                                    .foregroundColor(.primary)
                                                
                                                Text("Par \(days * 4) • \(days == 9 ? "Quick Competition" : "Full Championship")")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: durationDays == days ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(durationDays == days ? .green : .secondary)
                                                .font(.title2)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(durationDays == days ? Color.green.opacity(0.1) : Color(.systemGray6))
                                                .stroke(durationDays == days ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Start date section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Start Date", systemImage: "calendar")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            DatePicker("Tournament starts on", selection: $startDate, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // Tournament type section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Tournament Type", systemImage: isPublic ? "globe" : "lock.fill")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 12) {
                                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isPublic = false } }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Image(systemName: "lock.fill")
                                                    .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
                                                Text("Private Tournament")
                                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                                    .foregroundColor(.primary)
                                            }
                                            
                                            Text("Only players with the tournament ID can join")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: !isPublic ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(!isPublic ? Color(red: 0.224, green: 0.573, blue: 0.318) : .secondary)
                                            .font(.title2)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(!isPublic ? Color(red: 0.224, green: 0.573, blue: 0.318).opacity(0.1) : Color(.systemGray6))
                                            .stroke(!isPublic ? Color(red: 0.224, green: 0.573, blue: 0.318).opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isPublic = true } }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Image(systemName: "globe")
                                                    .foregroundColor(Color(red: 0.329, green: 0.549, blue: 0.753))
                                                Text("Public Tournament")
                                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                                    .foregroundColor(.primary)
                                            }
                                            
                                            Text("Anyone can discover and join this tournament")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: isPublic ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(isPublic ? Color(red: 0.329, green: 0.549, blue: 0.753) : .secondary)
                                            .font(.title2)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(isPublic ? Color(red: 0.329, green: 0.549, blue: 0.753).opacity(0.1) : Color(.systemGray6))
                                            .stroke(isPublic ? Color(red: 0.329, green: 0.549, blue: 0.753).opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Create button
                    Button(action: {
                        Task {
                            await createTournament()
                        }
                    }) {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.9)
                                    .tint(.white)
                            } else {
                                Image(systemName: isPublic ? "globe.badge.chevron.backward" : "flag.2.crossed.fill")
                                    .font(.title3)
                            }
                            
                            Text("Create Tournament")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(createTournamentButtonBackground)
                        )
                        .foregroundColor(.white)
                        .shadow(color: (tournamentName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading) ? .clear : Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    .disabled(tournamentName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { 
                        dismiss() 
                    }
                    .foregroundColor(.secondary)
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
                durationDays: durationDays,
                tournamentType: isPublic ? "public" : "private"
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
                        .foregroundColor(Color(red: 0.224, green: 0.573, blue: 0.318))
                    
                    Text("Enter the join code shared by your friend to join their tournament!")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 16) {
                    TextField("Join Code (e.g. A1B2C3D4)", text: $tournamentId)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .padding(.horizontal)
                    
                    Text("Enter the 8-character join code or full tournament ID.")
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
                    .background(tournamentId.trimmingCharacters(in: .whitespaces).isEmpty || isLoading ? Color.gray : Color(red: 0.224, green: 0.573, blue: 0.318))
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

// MARK: - Public Tournaments View

struct PublicTournamentsView: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = APIService.shared
    @State private var publicTournaments: [TournamentSummary] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var selectedTournament: TournamentSummary?
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var loadTask: Task<Void, Never>?
    @FocusState private var searchFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header section with search
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "globe.americas.fill")
                                .font(.title2)
                                .foregroundStyle(LinearGradient(colors: [Color(red: 0.329, green: 0.549, blue: 0.753), Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            
                            Text("Discover Tournaments")
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        
                        Text("Join public tournaments from around the world")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    
                    // Modern search bar
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(.body, weight: .medium))
                                .foregroundColor(searchFieldFocused ? .blue : .secondary)
                            
                            TextField("Search by tournament name...", text: $searchText)
                                .font(.system(.body, design: .rounded))
                                .focused($searchFieldFocused)
                                .onSubmit {
                                    Task {
                                        await searchTournaments()
                                    }
                                }
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    Task { await loadPublicTournaments() }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(.body, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                                .stroke(searchFieldFocused ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1.5)
                        )
                        .animation(.easeInOut(duration: 0.2), value: searchFieldFocused)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .background(
                    Color(.systemBackground)
                        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                )
                
                // Content area
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if publicTournaments.isEmpty && !isLoading {
                            EmptyStateView()
                                .padding(.top, 40)
                        } else {
                            ForEach(publicTournaments) { tournament in
                                PublicTournamentCard(tournament: tournament) {
                                    selectedTournament = tournament
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .refreshable {
                    await loadPublicTournaments()
                }
                
                // Loading overlay
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Finding tournaments...")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { 
                        dismiss()
                        onComplete()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                loadTask?.cancel()
                loadTask = Task {
                    await loadPublicTournaments()
                }
            }
            .onDisappear {
                loadTask?.cancel()
            }
            .sheet(item: $selectedTournament) { tournament in
                TournamentDetailView(tournament: tournament)
            }
            .alert("Tournament", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadPublicTournaments() async {
        guard !Task.isCancelled else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            publicTournaments = try await apiService.getPublicTournaments()
        } catch {
            // Don't show error if task was cancelled
            if !Task.isCancelled {
                alertMessage = "Failed to load public tournaments: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func searchTournaments() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            await loadPublicTournaments()
            return
        }
        
        guard !Task.isCancelled else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            publicTournaments = try await apiService.searchTournaments(query: searchText)
        } catch {
            // Don't show error if task was cancelled
            if !Task.isCancelled {
                alertMessage = "Failed to search tournaments: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Animated globe icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 0.329, green: 0.549, blue: 0.753).opacity(0.1), Color.cyan.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            
            VStack(spacing: 12) {
                Text("No Public Tournaments")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 8) {
                    Text("We couldn't find any public tournaments")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("Try adjusting your search or check back later!")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
    }
}

struct PublicTournamentCard: View {
    let tournament: TournamentSummary
    let onTap: () -> Void
    
    private var statusColor: Color {
        tournament.tournament.isActive ? .green : .orange
    }
    
    private var statusText: String {
        tournament.tournament.isActive ? "Active" : "Ended"
    }
    
    private var statusIcon: String {
        tournament.tournament.isActive ? "play.circle.fill" : "flag.checkered"
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Header with tournament info
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tournament.tournament.name)
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            HStack(spacing: 8) {
                                Label("Public", systemImage: "globe.americas.fill")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundColor(.blue)
                                
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("\(tournament.tournament.durationDays) Days")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Par \(tournament.tournament.durationDays * 4)")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Participant count badge
                        VStack(spacing: 4) {
                            Text("\(tournament.standings.count)")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundColor(.primary)
                            Text("players")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // Status and date row
                    HStack {
                        // Status badge
                        HStack(spacing: 6) {
                            Image(systemName: statusIcon)
                                .font(.system(.caption, weight: .semibold))
                                .foregroundColor(statusColor)
                            
                            Text(statusText)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundColor(statusColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(statusColor.opacity(0.1))
                        )
                        
                        Spacer()
                        
                        // Start date
                        Text(formatDateDisplay(tournament.tournament.startDate))
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                
                // Bottom accent strip
                Rectangle()
                    .fill(LinearGradient(colors: [Color(red: 0.329, green: 0.549, blue: 0.753), Color.cyan], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 3)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                    .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray5).opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
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
    
    private func formatDateDisplay(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            if Calendar.current.isDateInToday(date) {
                return "Today"
            } else if Calendar.current.isDateInTomorrow(date) {
                return "Tomorrow"
            } else {
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        }
        return dateString
    }
}

// MARK: - Animation and Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - View Extensions for Modern iOS Feel

extension View {
    func modernCard() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                    .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray5).opacity(0.3), lineWidth: 0.5)
            )
    }
    
    func modernButton(style: Color = .blue) -> some View {
        self
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: [style, style.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
            )
            .shadow(color: style.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}
