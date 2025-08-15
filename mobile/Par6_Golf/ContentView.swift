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
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Select Date")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .padding(.horizontal)
                            }
                            
                            VStack(spacing: 16) {
                                Text("Paste your Wordle share string:")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                TextEditor(text: $shareText)
                                    .frame(height: 120)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .padding(.horizontal)

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
                                        Text("Add Score")
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
        .onAppear {
            if apiService.isLoggedIn {
                Task {
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
