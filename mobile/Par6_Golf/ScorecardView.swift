//
//  ScorecardView.swift
//  Par6_Golf
//
//  Created by Claude on 8/29/25.
//

import SwiftUI

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
    @State private var showPenaltyInfo = false
    @AppStorage("hasSeenPenaltyInfo") private var hasSeenPenaltyInfo = false
    @State private var showPenaltyCoachMark = false
    
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    private func scoreString(_ golfScore: Int, isPenalty: Bool = false) -> String {
        switch golfScore {
        case -3: return "⛳"    // Ace (1/6)
        case -2: return "-2"   // Eagle (2/6) 
        case -1: return "-1"   // Birdie (3/6)
        case 0: return "E"     // Par (4/6)
        case 1: return "+1"    // Bogey (5/6)
        case 2: return "+2"    // Double Bogey (6/6)
        case 8: return isPenalty ? "🚫" : "+4"    // Penalty (+4) vs regular DNF
        default: return "+\(golfScore)"
        }
    }
    
    private func isPenaltyScore(_ score: Score) -> Bool {
        return score.scoreType == .penalty
    }
    
    private func scoreColor(_ score: Score) -> Color {
        if isPenaltyScore(score) {
            return Color.scoreRed // Use theme color for penalties
        }
        
        switch score.golfScore {
        case ...(-2): return Color.golfGreen // Great scores (ace, eagle)
        case -1: return Color.fairwayGreen   // Birdie
        case 0: return Color.parOrange       // Par
        case 1...2: return Color.secondaryText // Bogey, double bogey
        default: return Color.scoreRed       // Poor scores/DNF
        }
    }
    
    private func scoreBackgroundColor(_ score: Score) -> Color {
        if isPenaltyScore(score) {
            return Color.scoreRed.opacity(0.1) // Light red background for penalties
        }
        return Color.golfGreen.opacity(0.1) // Default green background
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
            
            // Check if we should show the penalty coach mark
            if !hasSeenPenaltyInfo && myScores.contains(where: { isPenaltyScore($0) }) {
                withAnimation {
                    showPenaltyCoachMark = true
                }
            }
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
            
            let existingScore = getScoreForSelectedDate()
            let wasUpdate = existingScore != nil
            let wasPenalty = existingScore?.scoreType == .penalty
            
            shareText = ""
            
            if wasPenalty {
                alertMessage = "Penalty score overridden for \(shortDate(selectedDate))! Your submitted score has replaced the missed day penalty."
            } else {
                alertMessage = wasUpdate ? "Score updated for \(shortDate(selectedDate))!" : "Score added for \(shortDate(selectedDate))!"
            }
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
                            HStack {
                                Text("My Recent Scores")
                                    .font(.headline)
                                Spacer()
                                
                                // Show coach mark on first penalty, then just icon
                                if myScores.contains(where: { isPenaltyScore($0) }) {
                                    if !hasSeenPenaltyInfo && showPenaltyCoachMark {
                                        // First-time coach mark
                                        HStack(spacing: 6) {
                                            Text("🚫 = missed day")
                                                .font(.caption)
                                                .foregroundColor(.scoreRed)
                                            
                                            Button("Got it") {
                                                withAnimation {
                                                    hasSeenPenaltyInfo = true
                                                    showPenaltyCoachMark = false
                                                }
                                            }
                                            .font(.caption)
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)
                                            .tint(.golfGreen)
                                        }
                                        .transition(.scale.combined(with: .opacity))
                                    } else {
                                        // Persistent subtle affordance
                                        Button(action: {
                                            showPenaltyInfo = true
                                        }) {
                                            Image(systemName: "info.circle")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(myScores.sorted(by: { $0.puzzleDate > $1.puzzleDate }).prefix(10), id: \.id) { score in
                                        VStack(spacing: 4) {
                                            HStack(spacing: 2) {
                                                Text(formatPuzzleDate(score.puzzleDate))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                if isPenaltyScore(score) {
                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                        .font(.system(size: 8))
                                                        .foregroundColor(.scoreRed)
                                                }
                                            }
                                            Text(scoreString(score.golfScore, isPenalty: isPenaltyScore(score)))
                                                .font(.title2)
                                                .bold()
                                                .foregroundColor(scoreColor(score))
                                        }
                                        .frame(width: 60, height: 60)
                                        .background(scoreBackgroundColor(score))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    isPenaltyScore(score) ? Color.scoreRed.opacity(0.3) : Color.clear,
                                                    lineWidth: 1.5
                                                )
                                        )
                                        .onLongPressGesture {
                                            if isPenaltyScore(score) {
                                                showPenaltyInfo = true
                                            }
                                        }
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
                                            HStack(spacing: 4) {
                                                Text("Current Score:")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                if isPenaltyScore(existingScore) {
                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                        .font(.system(size: 8))
                                                        .foregroundColor(.scoreRed)
                                                    Text("(penalty)")
                                                        .font(.caption)
                                                        .foregroundColor(.scoreRed)
                                                }
                                            }
                                            Spacer()
                                            Text(scoreString(existingScore.golfScore, isPenalty: isPenaltyScore(existingScore)))
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(isPenaltyScore(existingScore) ? .scoreRed : .orange)
                                            if !isPenaltyScore(existingScore) {
                                                Text("(will be updated)")
                                                    .font(.caption)
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                        .padding(8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isPenaltyScore(existingScore) ? Color.scoreRed.opacity(0.05) : Color.orange.opacity(0.05))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    isPenaltyScore(existingScore) ? Color.scoreRed.opacity(0.2) : Color.orange.opacity(0.2),
                                                    lineWidth: 1
                                                )
                                        )
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
                                        
                                        let existingScore = getScoreForSelectedDate()
                                        let isPenalty = existingScore?.scoreType == .penalty
                                        
                                        if isPenalty {
                                            Text("Override Penalty for \(formatSelectedDateShort())")
                                        } else {
                                            Text(existingScore != nil ? "Update Score for \(formatSelectedDateShort())" : "Add Score for \(formatSelectedDateShort())")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background({
                                        let existingScore = getScoreForSelectedDate()
                                        let isPenalty = existingScore?.scoreType == .penalty
                                        let isEmpty = shareText.trimmingCharacters(in: .whitespaces).isEmpty
                                        
                                        if isEmpty || isLoading {
                                            return Color.gray
                                        } else if isPenalty {
                                            return Color.parOrange // Use warning color for penalty override
                                        } else {
                                            return Color.green
                                        }
                                    }())
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
        .sheet(isPresented: $showPenaltyInfo) {
            VStack(spacing: 0) {
                // Scrollable content
                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.scoreRed)
                                .padding(.top, 20)
                            
                            Text("Penalty Scores")
                                .font(.title2.bold())
                            
                            Text("Missed days = +4 strokes")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 28)
                        
                        // Content sections
                        VStack(spacing: 20) {
                            // What section
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "questionmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 20))
                                    Text("What happens when I miss a day?")
                                        .font(.headline)
                                    Spacer()
                                }
                                
                                Text("If you don't submit your Wordle by midnight, you'll automatically receive a **+4 penalty** (🚫) for that puzzle.")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            // Why section
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "scale.3d")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 20))
                                    Text("Why do penalties exist?")
                                        .font(.headline)
                                    Spacer()
                                }
                                
                                Text("Just like in golf, consistency matters. Penalties ensure fair competition by preventing players from cherry-picking easy puzzles.")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            // Fix section
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 20))
                                    Text("Can I override a penalty?")
                                        .font(.headline)
                                    Spacer()
                                }
                                
                                Text("Yes! Submit your actual score anytime to replace the penalty. Your real result will override the +4.")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
                
                // Fixed bottom button
                VStack(spacing: 0) {
                    Divider()
                    
                    Button(action: {
                        showPenaltyInfo = false
                    }) {
                        Text("Got it")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Color(UIColor.systemBackground))
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .alert("Info", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

#Preview {
    ScorecardView()
}