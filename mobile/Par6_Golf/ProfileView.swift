//
//  ProfileView.swift
//  Par6_Golf
//
//  Created by Claude on 8/29/25.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var apiService = APIService.shared
    @State private var showRules = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if apiService.isLoggedIn {
                    // Header with tab selector
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Par6 Golf")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundColor(.golfGreen)
                            
                            if let user = apiService.currentUser {
                                Text("@\(user.handle)")
                                    .font(.system(.title2, design: .rounded))
                                    .foregroundColor(.secondaryText)
                            }
                        }
                        
                        // Tab Selector
                        Picker("Profile Sections", selection: $selectedTab) {
                            Text("My Stats").tag(0)
                            Text("Game Info").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                    
                    // Tab Content
                    TabView(selection: $selectedTab) {
                        // Stats Tab
                        UserStatsView()
                            .tag(0)
                        
                        // Game Info Tab
                        GameInfoView(showRules: $showRules) {
                            apiService.logout()
                        }
                        .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: selectedTab)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Profile")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showRules) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Scoring Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Scoring", systemImage: "flag.fill")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.golfGreen)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("1 guess")
                                    Spacer()
                                    Text("⛳ Ace (-3)")
                                }
                                HStack {
                                    Text("2 guesses")
                                    Spacer()
                                    Text("Eagle (-2)")
                                }
                                HStack {
                                    Text("3 guesses")
                                    Spacer()
                                    Text("Birdie (-1)")
                                }
                                HStack {
                                    Text("4 guesses")
                                    Spacer()
                                    Text("Par (E)")
                                }
                                HStack {
                                    Text("5 guesses")
                                    Spacer()
                                    Text("Bogey (+1)")
                                }
                                HStack {
                                    Text("6 guesses")
                                    Spacer()
                                    Text("Double Bogey (+2)")
                                }
                                HStack {
                                    Text("Failed (X/6)")
                                    Spacer()
                                    Text("DNF (+4)")
                                }
                            }
                            .font(.body)
                            .padding()
                            .background(Color.golfGreen.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // Penalty Scores Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Penalty Scores", systemImage: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.scoreRed)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("**What are penalties?**")
                                Text("If you don't submit a Wordle score by end of day, you'll receive a +4 penalty (🚫) for that date.")
                                
                                Text("**Why penalties?**")
                                Text("Penalties keep tournaments fair by preventing players from skipping difficult puzzles. Just like in golf, every day counts!")
                                
                                Text("**Can I fix a penalty?**")
                                Text("Yes! Submit your actual Wordle score to replace any penalty. Your real score will override the +4.")
                            }
                            .font(.body)
                            .padding()
                            .background(Color.scoreRed.opacity(0.05))
                            .cornerRadius(12)
                        }
                        
                        // Tournaments Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Tournaments", systemImage: "trophy.fill")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.parOrange)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("**How tournaments work:**")
                                Text("• Create or join tournaments with friends")
                                Text("• Compete over multiple days")
                                Text("• Lowest total score wins")
                                Text("• Live leaderboards update daily")
                            }
                            .font(.body)
                            .padding()
                            .background(Color.parOrange.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Game Rules")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showRules = false
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Game Info View

struct GameInfoView: View {
    @Binding var showRules: Bool
    let onSignOut: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    // Quick Stats Card
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.title3)
                                .foregroundColor(.golfGreen)
                            
                            Text("Game Information")
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .foregroundColor(.primaryText)
                            
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(title: "Game Type", value: "Wordle Golf Scoring")
                            InfoRow(title: "Par Score", value: "4 guesses (E)")
                            InfoRow(title: "Best Possible", value: "1 guess (Ace)")
                            InfoRow(title: "Tournament Length", value: "9 or 18 days")
                        }
                    }
                    .padding(20)
                    .golfCard()
                    
                    // Game Rules Button
                    Button(action: { showRules = true }) {
                        HStack {
                            Label("Complete Game Rules", systemImage: "book.fill")
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .foregroundColor(.golfGreen)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.golfGreen.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer(minLength: 60)
                
                // Sign Out Button
                VStack(spacing: 12) {
                    Button(action: onSignOut) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(.body, weight: .medium))
                            Text("Sign Out")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                        .foregroundColor(.scoreRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.scoreRed.opacity(0.3), lineWidth: 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.scoreRed.opacity(0.05))
                                )
                        )
                    }
                    
                    Text("You can always sign back in with your handle")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.secondaryText)
            Spacer()
            Text(value)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundColor(.primaryText)
        }
    }
}

#Preview {
    ProfileView()
}