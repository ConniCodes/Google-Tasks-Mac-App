import Combine
import Foundation
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Provides the current access token for Google API calls.
/// Uses Google Sign-In when available; otherwise use your own OAuth flow and set the token.
final class GoogleAuthManager: ObservableObject {
    static let tasksScope = "https://www.googleapis.com/auth/tasks"
    
    @Published private(set) var isSignedIn = false
    @Published private(set) var currentUserEmail: String?
    /// First letter of the signed-in user's name (or email), for avatar. "U" when not available.
    @Published private(set) var userInitial: String = "U"
    
    private var accessToken: String?
    
    init() {}
    
#if canImport(GoogleSignIn)
    func signIn(presentingWindow: NSWindow?) async throws {
        guard let presentingWindow = presentingWindow else { return }
        
        let config = GIDConfiguration(clientID: GoogleAuthManager.clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        var result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingWindow)
        let hasTasksScope = result.user.grantedScopes?.contains(GoogleAuthManager.tasksScope) ?? false
        if !hasTasksScope {
            result = try await result.user.addScopes([GoogleAuthManager.tasksScope], presenting: presentingWindow)
        }
        await MainActor.run {
            isSignedIn = true
            currentUserEmail = result.user.profile?.email
            userInitial = Self.initial(from: result.user.profile)
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        Task { @MainActor in
            isSignedIn = false
            currentUserEmail = nil
            userInitial = "U"
            accessToken = nil
        }
    }
    
    func getAccessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw AuthError.notSignedIn
        }
        do {
            let updatedUser = try await user.refreshTokensIfNeeded()
            return updatedUser.accessToken.tokenString
        } catch {
            throw AuthError.tokenRefreshFailed(error.localizedDescription)
        }
    }
    
    func restorePreviousSignIn() async {
        try? await GIDSignIn.sharedInstance.restorePreviousSignIn()
        await MainActor.run {
            let user = GIDSignIn.sharedInstance.currentUser
            isSignedIn = user != nil
            currentUserEmail = user?.profile?.email
            userInitial = user.map { Self.initial(from: $0.profile) } ?? "U"
        }
    }
    
    private static func initial(from profile: GIDProfileData?) -> String {
        guard let profile = profile else { return "U" }
        if let first = profile.givenName?.first { return String(first).uppercased() }
        if let first = profile.familyName?.first { return String(first).uppercased() }
        if let first = profile.name.first { return String(first).uppercased() }
        if let first = profile.email.first { return String(first).uppercased() }
        return "U"
    }
    
    /// Set your OAuth client ID from Google Cloud Console (macOS client).
    static var clientID: String {
        (Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String)
            ?? ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"]
            ?? ""
    }
#else
    func signIn(presentingWindow: NSWindow?) async throws {
        throw AuthError.notConfigured
    }
    
    func signOut() {
        Task { @MainActor in
            isSignedIn = false
            currentUserEmail = nil
            accessToken = nil
        }
    }
    
    func getAccessToken() async throws -> String {
        if let token = accessToken { return token }
        throw AuthError.notSignedIn
    }
    
    func setAccessToken(_ token: String) {
        accessToken = token
        isSignedIn = true
    }
    
    func restorePreviousSignIn() async {}
#endif
}

enum AuthError: LocalizedError {
    case notSignedIn
    case tokenRefreshFailed(String)
    case notConfigured
    
    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Not signed in to Google"
        case .tokenRefreshFailed(let msg): return "Token refresh failed: \(msg)"
        case .notConfigured: return "Add GoogleSignIn SDK and set GOOGLE_CLIENT_ID"
        }
    }
}
