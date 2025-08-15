//
//  APIService.swift
//  Par6_Golf
//
//  Created by Claude on 8/11/25.
//

import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int, String)
    case networkError(Error)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized - please log in again"
        }
    }
}

@MainActor
class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL: String = {
        return ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "https://9d4oqidsq0.execute-api.us-west-2.amazonaws.com/dev/api"
    }()
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    @Published var sessionToken: String?
    @Published var currentUser: User?
    
    private let keychain = "par6_session_token"
    private let userDefaults = UserDefaults.standard
    
    private init() {
        setupDateFormatting()
        restoreSession()
    }
    
    private func setupDateFormatting() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        decoder.dateDecodingStrategy = .formatted(formatter)
        encoder.dateEncodingStrategy = .formatted(formatter)
    }
    
    // MARK: - Session Persistence
    
    private func saveSession() {
        if let token = sessionToken {
            userDefaults.set(token, forKey: keychain)
        }
        
        if let user = currentUser {
            let userData = try? encoder.encode(user)
            userDefaults.set(userData, forKey: "par6_current_user")
        }
    }
    
    private func restoreSession() {
        // Restore session token
        if let savedToken = userDefaults.string(forKey: keychain) {
            sessionToken = savedToken
        }
        
        // Restore user data
        if let userData = userDefaults.data(forKey: "par6_current_user") {
            currentUser = try? decoder.decode(User.self, from: userData)
        }
        
        // Validate session in background if we have both token and user
        if sessionToken != nil && currentUser != nil {
            Task {
                await validateSession()
            }
        }
    }
    
    private func clearSession() {
        sessionToken = nil
        currentUser = nil
        userDefaults.removeObject(forKey: keychain)
        userDefaults.removeObject(forKey: "par6_current_user")
    }
    
    private func validateSession() async {
        // Try to make a simple authenticated request to validate the session
        do {
            let _: [Score] = try await makeRequest(
                endpoint: "/scores?start_date=2024-01-01&end_date=2024-01-01",
                requiresAuth: true
            )
            // Session is valid, keep current state
        } catch {
            // Session is invalid, clear it
            await MainActor.run {
                clearSession()
            }
        }
    }
    
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth, let token = sessionToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(URLError(.badServerResponse))
            }
            
            if httpResponse.statusCode == 401 {
                clearSession()
                throw APIError.unauthorized
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(httpResponse.statusCode, errorMessage)
            }
            
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    // MARK: - User Management
    
    func createUser(handle: String) async throws -> UserResponse {
        let userCreate = UserCreate(handle: handle)
        let body = try encoder.encode(userCreate)
        
        let response: UserResponse = try await makeRequest(
            endpoint: "/users",
            method: "POST",
            body: body
        )
        
        sessionToken = response.sessionToken
        currentUser = User(
            userId: response.userId,
            handle: response.handle,
            createdAt: Date()
        )
        
        // Save session for persistence
        saveSession()
        
        return response
    }
    
    // MARK: - Score Management
    
    func submitScore(
        puzzleDate: String,
        status: Status,
        guessesUsed: Int? = nil,
        sourceText: String? = nil
    ) async throws -> Score {
        guard let userId = currentUser?.userId else {
            throw APIError.unauthorized
        }
        
        let scoreCreate = ScoreCreate(
            userId: userId,
            puzzleDate: puzzleDate,
            status: status,
            guessesUsed: guessesUsed,
            sourceText: sourceText
        )
        
        let body = try encoder.encode(scoreCreate)
        
        return try await makeRequest(
            endpoint: "/scores",
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }
    
    func getUserScores(startDate: String, endDate: String) async throws -> [Score] {
        return try await makeRequest(
            endpoint: "/scores?start_date=\(startDate)&end_date=\(endDate)",
            requiresAuth: true
        )
    }
    
    // MARK: - Leaderboard
    
    func getLeaderboard(startDate: String, endDate: String, limit: Int = 50) async throws -> [LeaderboardEntry] {
        return try await makeRequest(
            endpoint: "/leaderboard?start_date=\(startDate)&end_date=\(endDate)&limit=\(limit)"
        )
    }
    
    // MARK: - Tournament Management
    
    func createTournament(name: String, startDate: String) async throws -> Tournament {
        let body = try encoder.encode([
            "name": name,
            "start_date": startDate
        ])
        
        return try await makeRequest(
            endpoint: "/tournaments",
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }
    
    func getTournaments() async throws -> [TournamentSummary] {
        return try await makeRequest(
            endpoint: "/tournaments",
            requiresAuth: true
        )
    }
    
    func joinTournament(tournamentId: String) async throws -> Tournament {
        let body = try encoder.encode(["tournament_id": tournamentId])
        
        return try await makeRequest(
            endpoint: "/tournaments/\(tournamentId)/join",
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }
    
    func getTournamentDetails(tournamentId: String) async throws -> TournamentSummary {
        return try await makeRequest(
            endpoint: "/tournaments/\(tournamentId)",
            requiresAuth: true
        )
    }
    
    func shareTournament(tournamentId: String) -> String {
        return "Join my Par6 Golf tournament! Tournament ID: \(tournamentId)\n\nDownload Par6 Golf to compete in our 18-day Wordle golf match!"
    }
    
    // MARK: - Utility
    
    func logout() {
        clearSession()
    }
    
    var isLoggedIn: Bool {
        sessionToken != nil && currentUser != nil
    }
}