//
//  ContentView.swift
//  Par6_Golf
//
//  Created by Cole Michael Riddlebarger on 6/4/25.
//

import SwiftUI
import Foundation
import Combine

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

#Preview {
    ContentView()
        .environmentObject(DeepLinkManager())
}