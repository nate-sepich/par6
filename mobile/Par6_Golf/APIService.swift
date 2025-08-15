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
    
    private init() {
        setupDateFormatting()
    }
    
    private func setupDateFormatting() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        decoder.dateDecodingStrategy = .formatted(formatter)
        encoder.dateEncodingStrategy = .formatted(formatter)
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
                sessionToken = nil
                currentUser = nil
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
    
    // MARK: - Utility
    
    func logout() {
        sessionToken = nil
        currentUser = nil
    }
    
    var isLoggedIn: Bool {
        sessionToken != nil && currentUser != nil
    }
}