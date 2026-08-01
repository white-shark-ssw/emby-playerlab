import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var session: EmbySession?
    @Published var isWorking = false
    @Published var errorMessage: String?

    private let sessionKey = "EmbyPlayerLab.Session"

    func restore() {
        guard session == nil,
              let data = UserDefaults.standard.data(forKey: sessionKey),
              let stored = try? JSONDecoder().decode(EmbySession.self, from: data),
              KeychainStore.get(account: stored.tokenAccount) != nil else { return }
        session = stored
    }

    func login(serverText: String, username: String, password: String) async {
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
            let data = try JSONEncoder().encode(stored)
            UserDefaults.standard.set(data, forKey: sessionKey)
            session = stored
            DiagnosticsLogger.shared.log("Session", "Login success server=\(stored.serverName) version=\(stored.serverVersion)")
        } catch {
            errorMessage = error.localizedDescription
            DiagnosticsLogger.shared.log("Session", "Login failed: \(error.localizedDescription)")
        }
    }

    func client() throws -> EmbyAPIClient {
        guard let session,
              let token = KeychainStore.get(account: session.tokenAccount) else {
            throw EmbyAPIError.missingSession
        }
        return EmbyAPIClient(baseURL: session.serverURL, accessToken: token, userId: session.user.id)
    }

    func logout() async {
        if let session, let token = KeychainStore.get(account: session.tokenAccount) {
            let client = EmbyAPIClient(baseURL: session.serverURL, accessToken: token, userId: session.user.id)
            await client.logout()
            KeychainStore.remove(account: session.tokenAccount)
        }
        UserDefaults.standard.removeObject(forKey: sessionKey)
        session = nil
    }

    private func normalizedServerURL(_ input: String) throws -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EmbyAPIError.invalidServerURL }
        let value = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host != nil else {
            throw EmbyAPIError.invalidServerURL
        }
        components.path = components.path.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        guard let url = components.url else { throw EmbyAPIError.invalidServerURL }
        return url
    }
}
