//
//  Par6_GolfApp.swift
//  Par6_Golf
//
//  Created by Cole Michael Riddlebarger on 6/4/25.
//

import SwiftUI

@main
struct Par6_GolfApp: App {
    @StateObject private var deepLinkManager = DeepLinkManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deepLinkManager)
                .onOpenURL { url in
                    deepLinkManager.handleDeepLink(url: url)
                }
        }
    }
}

class DeepLinkManager: ObservableObject {
    @Published var pendingTournamentJoin: String?
    
    func handleDeepLink(url: URL) {
        print("[DEEP LINK DEBUG] Received URL: \(url)")
        print("[DEEP LINK DEBUG] Scheme: \(url.scheme ?? "nil")")
        print("[DEEP LINK DEBUG] Host: \(url.host ?? "nil")")
        print("[DEEP LINK DEBUG] Path: \(url.path)")
        print("[DEEP LINK DEBUG] Path components: \(url.pathComponents)")
        
        // Handle both par6golf:// and https://par6.golf/ URLs
        if url.scheme == "par6golf" {
            if url.host == "join" {
                let pathComponents = url.pathComponents
                if pathComponents.count >= 2 {
                    let tournamentCode = pathComponents[1]
                    print("[DEEP LINK DEBUG] Setting pending tournament join: \(tournamentCode)")
                    pendingTournamentJoin = tournamentCode
                } else {
                    print("[DEEP LINK DEBUG] Not enough path components: \(pathComponents)")
                }
            } else {
                print("[DEEP LINK DEBUG] Host is not 'join': \(url.host ?? "nil")")
            }
        } else if url.scheme == "https" && url.host == "par6.golf" {
            // Handle https://par6.golf/join/CODE
            let pathComponents = url.pathComponents
            if pathComponents.count >= 3 && pathComponents[1] == "join" {
                let tournamentCode = pathComponents[2]
                print("[DEEP LINK DEBUG] Setting pending tournament join from HTTPS: \(tournamentCode)")
                pendingTournamentJoin = tournamentCode
            } else {
                print("[DEEP LINK DEBUG] Invalid HTTPS path: \(pathComponents)")
            }
        } else {
            print("[DEEP LINK DEBUG] Scheme/host not supported: \(url.scheme ?? "nil")://\(url.host ?? "nil")")
        }
    }
    
    func clearPendingJoin() {
        pendingTournamentJoin = nil
    }
}
