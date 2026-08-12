import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [EmbySession] = []
    @Published private(set) var session: EmbySession?
    @Published var isWorking = false
    @Published var errorMessage: String?

    private let sessionsKey = "OSPlayer.Sessions"
    private let legacySessionKey = "EmbyPlayerLab.Session"
    private var didRestore = false

    func restore() {
        guard !didRestore else { return }
        didRestore = true

        if let data = UserDefaults.standard.data(forKey: sessionsKey), let stored = try? JSONDecoder().decode([EmbySession].self, from: data) {
            sessions = stored.filter { KeychainStore.get(account: $0.tokenAccount) != nil }
            persistSessions()
            return
        }

        guard let data = UserDefaults.standard.data(forKey: legacySessionKey),
              let stored = try? JSONDecoder().decode(EmbySession.self, from: data),
              KeychainStore.get(account: stored.tokenAccount) != nil else { return }
        sessions = [stored]
        persistSessions()
        UserDefaults.standard.removeObject(forKey: legacySessionKey)
    }

    func login(serverText: String, username: String, password: String) async {
        _ = await addServer(serverText: serverText, username: username, password: password, activate: true)
    }

    @discardableResult
    func addServer(serverText: String, username: String, password: String, activate: Bool = false) async -> EmbySession? {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            let baseURL = try normalizedServerURL(serverText)
            let anonymous = EmbyAPIClient(baseURL: baseURL)
            async let infoRequest = anonymous.publicInfo()
            async let authRequest = anonymous.authenticate(username: username, password: password)
            let (info, auth) = try await (infoRequest, authRequest)

            let serverId = auth.serverId ?? info.id ?? baseURL.host ?? "unknown-server"
            let tokenAccount = "\(serverId):\(auth.user.id)"
            try KeychainStore.set(auth.accessToken, account: tokenAccount)

            let stored = EmbySession(
                serverURL: baseURL,
                serverId: serverId,
                serverName: info.serverName ?? "Emby",
                serverVersion: info.version ?? "未知",
                user: auth.user,
                tokenAccount: tokenAccount
            )

            if let index = sessions.firstIndex(where: { $0.id == stored.id }) {
                sessions[index] = stored
            } else {
                sessions.append(stored)
            }
            sessions.sort { $0.serverName.localizedCaseInsensitiveCompare($1.serverName) == .orderedAscending }
            persistSessions()
            if activate { session = stored }
            DiagnosticsLogger.shared.log("Session", "Server saved server=\(stored.serverName) version=\(stored.serverVersion) user=\(stored.user.name)")
            return stored
        } catch {
            errorMessage = error.localizedDescription
            DiagnosticsLogger.shared.log("Session", "Server add failed: \(error.localizedDescription)")
            return nil
        }
    }

    func activate(_ stored: EmbySession) {
        guard sessions.contains(where: { $0.id == stored.id }), KeychainStore.get(account: stored.tokenAccount) != nil else { return }
        session = stored
    }

    func leaveServer() {
        session = nil
    }

    func client() throws -> EmbyAPIClient {
        guard let session else { throw EmbyAPIError.missingSession }
        return try client(for: session)
    }

    func client(for stored: EmbySession) throws -> EmbyAPIClient {
        guard let token = KeychainStore.get(account: stored.tokenAccount) else { throw EmbyAPIError.missingSession }
        return EmbyAPIClient(baseURL: stored.serverURL, accessToken: token, userId: stored.user.id, serverName: stored.serverName)
    }

    func remove(_ stored: EmbySession) async {
        if let token = KeychainStore.get(account: stored.tokenAccount) {
            let client = EmbyAPIClient(baseURL: stored.serverURL, accessToken: token, userId: stored.user.id)
            await client.logout()
            KeychainStore.remove(account: stored.tokenAccount)
        }
        sessions.removeAll { $0.id == stored.id }
        if session?.id == stored.id { session = nil }
        persistSessions()
        DiagnosticsLogger.shared.log("Session", "Server removed server=\(stored.serverName) user=\(stored.user.name)")
    }

    func logout() async {
        guard let session else { return }
        await remove(session)
    }

    private func persistSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    private func normalizedServerURL(_ input: String) throws -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EmbyAPIError.invalidServerURL }
        let value = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host != nil else { throw EmbyAPIError.invalidServerURL }
        components.path = components.path.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        guard let url = components.url else { throw EmbyAPIError.invalidServerURL }
        return url
    }
}
