import Foundation
import Combine

struct EmbyServerConfiguration: Codable, Equatable {
    let sessionID: String
    var serverURLs: [URL]
    var iCloudSyncEnabled: Bool
    var updatedAt: Date
}

struct EmbyRouteProbe: Identifiable, Equatable {
    let input: String
    let url: URL?
    let latencyMS: Int?
    let serverId: String?
    let serverName: String?
    let serverVersion: String?
    let errorDescription: String?
    let matchesExpectedServer: Bool

    var id: String { input }
    var isReachable: Bool { url != nil && errorDescription == nil }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [EmbySession] = []
    @Published private(set) var session: EmbySession?
    @Published private(set) var autoStartSessionID: String?
    @Published var isWorking = false
    @Published var errorMessage: String?

    private let sessionsKey = "OSPlayer.Sessions"
    private let configurationsKey = "OSPlayer.ServerConfigurations"
    private let autoStartKey = "OSPlayer.AutoStartSession"
    private let legacySessionKey = "EmbyPlayerLab.Session"
    private let syncedRegistryAccount = "OnePlayer.SyncedServers.v1"
    private var configurations: [String: EmbyServerConfiguration] = [:]
    private var didRestore = false

    var autoStartSession: EmbySession? {
        guard let autoStartSessionID else { return nil }
        return sessions.first { $0.id == autoStartSessionID }
    }

    func restore() {
        guard !didRestore else { return }
        didRestore = true

        configurations = loadConfigurations()
        autoStartSessionID = UserDefaults.standard.string(forKey: autoStartKey)

        var restored: [EmbySession] = []
        if let data = UserDefaults.standard.data(forKey: sessionsKey), let stored = try? JSONDecoder().decode([EmbySession].self, from: data) {
            restored = stored
        } else if let data = UserDefaults.standard.data(forKey: legacySessionKey),
                  let stored = try? JSONDecoder().decode(EmbySession.self, from: data) {
            restored = [stored]
            UserDefaults.standard.removeObject(forKey: legacySessionKey)
        }

        mergeSyncedSessions(into: &restored)
        sessions = restored.filter { KeychainStore.get(account: $0.tokenAccount) != nil }
        let validSessionIDs = Set(sessions.map(\.id))
        configurations = configurations.filter { validSessionIDs.contains($0.key) }
        if let autoStartSessionID, !validSessionIDs.contains(autoStartSessionID) { self.autoStartSessionID = nil }
        persistLocalState()
    }

    func login(serverText: String, username: String, password: String) async {
        _ = await addServer(serverText: serverText, username: username, password: password, activate: true)
    }

    @discardableResult
    func addServer(serverText: String, username: String, password: String, activate: Bool = false, additionalServerTexts: [String] = [], autoStart: Bool = false, iCloudSync: Bool = false) async -> EmbySession? {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            let routes = try normalizedRoutes([serverText] + additionalServerTexts)
            let probes = await probeServerRoutes(serverTexts: routes.map { $0.absoluteString })
            let best = try validatedBestProbe(probes, expectedServerId: nil, requiresSharedIdentity: routes.count > 1)
            guard let baseURL = best.url else { throw SessionStoreError.noAvailableRoute }

            let anonymous = EmbyAPIClient(baseURL: baseURL)
            let auth = try await anonymous.authenticate(username: username, password: password)
            let serverId = auth.serverId ?? best.serverId ?? baseURL.host ?? "unknown-server"
            if let probeServerId = best.serverId, let authServerId = auth.serverId, probeServerId != authServerId { throw SessionStoreError.routeIdentityMismatch }

            let tokenAccount = "\(serverId):\(auth.user.id)"
            try KeychainStore.set(auth.accessToken, account: tokenAccount)

            let stored = EmbySession(
                serverURL: baseURL,
                serverId: serverId,
                serverName: best.serverName ?? "Emby",
                serverVersion: best.serverVersion ?? "未知",
                user: auth.user,
                tokenAccount: tokenAccount
            )

            if let index = sessions.firstIndex(where: { $0.id == stored.id }) { sessions[index] = stored }
            else { sessions.append(stored) }
            sessions.sort { $0.serverName.localizedCaseInsensitiveCompare($1.serverName) == .orderedAscending }
            configurations[stored.id] = EmbyServerConfiguration(sessionID: stored.id, serverURLs: routes, iCloudSyncEnabled: iCloudSync, updatedAt: Date())
            if autoStart { autoStartSessionID = stored.id }
            else if autoStartSessionID == stored.id { autoStartSessionID = nil }
            persistSessions()
            if activate { session = stored }
            DiagnosticsLogger.shared.log("Session", "Server saved server=\(stored.serverName) version=\(stored.serverVersion) user=\(stored.user.name) routes=\(routes.count) autoStart=\(autoStart) iCloud=\(iCloudSync)")
            return stored
        } catch {
            errorMessage = error.localizedDescription
            DiagnosticsLogger.shared.log("Session", "Server add failed: \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    func updateServer(_ stored: EmbySession, serverTexts: [String], autoStart: Bool, iCloudSync: Bool) async -> EmbySession? {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            guard KeychainStore.get(account: stored.tokenAccount) != nil else { throw EmbyAPIError.missingSession }
            let routes = try normalizedRoutes(serverTexts)
            let probes = await probeServerRoutes(serverTexts: routes.map { $0.absoluteString }, expectedServerId: stored.serverId)
            let best = try validatedBestProbe(probes, expectedServerId: stored.serverId, requiresSharedIdentity: true)
            guard let baseURL = best.url else { throw SessionStoreError.noAvailableRoute }

            let updated = EmbySession(
                serverURL: baseURL,
                serverId: stored.serverId,
                serverName: best.serverName ?? stored.serverName,
                serverVersion: best.serverVersion ?? stored.serverVersion,
                user: stored.user,
                tokenAccount: stored.tokenAccount
            )
            guard let index = sessions.firstIndex(where: { $0.id == stored.id }) else { throw EmbyAPIError.missingSession }
            sessions[index] = updated
            configurations[stored.id] = EmbyServerConfiguration(sessionID: stored.id, serverURLs: routes, iCloudSyncEnabled: iCloudSync, updatedAt: Date())
            if autoStart { autoStartSessionID = stored.id }
            else if autoStartSessionID == stored.id { autoStartSessionID = nil }
            if session?.id == stored.id { session = updated }
            persistSessions()
            DiagnosticsLogger.shared.log("Session", "Server updated server=\(updated.serverName) routes=\(routes.count) autoStart=\(autoStart) iCloud=\(iCloudSync)")
            return updated
        } catch {
            errorMessage = error.localizedDescription
            DiagnosticsLogger.shared.log("Session", "Server update failed: \(error.localizedDescription)")
            return nil
        }
    }

    func routes(for stored: EmbySession) -> [URL] {
        let saved = configurations[stored.id]?.serverURLs ?? [stored.serverURL]
        var seen = Set<String>()
        return saved.filter { seen.insert($0.absoluteString).inserted }
    }

    func isAutoStart(_ stored: EmbySession) -> Bool { autoStartSessionID == stored.id }

    func iCloudSyncEnabled(for stored: EmbySession) -> Bool { configurations[stored.id]?.iCloudSyncEnabled ?? false }

    func probeServerRoutes(serverTexts: [String], expectedServerId: String? = nil) async -> [EmbyRouteProbe] {
        var invalid: [EmbyRouteProbe] = []
        var valid: [(String, URL)] = []
        var seen = Set<String>()

        for raw in serverTexts {
            let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !input.isEmpty else { continue }
            do {
                let url = try normalizedServerURL(input)
                guard seen.insert(url.absoluteString).inserted else { continue }
                valid.append((url.absoluteString, url))
            } catch {
                invalid.append(EmbyRouteProbe(input: input, url: nil, latencyMS: nil, serverId: nil, serverName: nil, serverVersion: nil, errorDescription: error.localizedDescription, matchesExpectedServer: false))
            }
        }

        let measured = await withTaskGroup(of: EmbyRouteProbe.self) { group in
            for (input, url) in valid {
                group.addTask {
                    let started = Date()
                    do {
                        let info = try await EmbyAPIClient(baseURL: url).publicInfo()
                        let elapsed = max(0, Int(Date().timeIntervalSince(started) * 1_000))
                        let matches = expectedServerId == nil || info.id == expectedServerId
                        return EmbyRouteProbe(input: input, url: url, latencyMS: elapsed, serverId: info.id, serverName: info.serverName, serverVersion: info.version, errorDescription: nil, matchesExpectedServer: matches)
                    } catch {
                        return EmbyRouteProbe(input: input, url: url, latencyMS: nil, serverId: nil, serverName: nil, serverVersion: nil, errorDescription: error.localizedDescription, matchesExpectedServer: false)
                    }
                }
            }
            var values: [EmbyRouteProbe] = []
            for await value in group { values.append(value) }
            return values
        }
        let order = Dictionary(uniqueKeysWithValues: valid.enumerated().map { ($0.element.0, $0.offset) })
        return (measured + invalid).sorted { (order[$0.input] ?? Int.max) < (order[$1.input] ?? Int.max) }
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

    func clientForBestRoute(for stored: EmbySession) async throws -> EmbyAPIClient {
        guard let token = KeychainStore.get(account: stored.tokenAccount) else { throw EmbyAPIError.missingSession }
        let candidates = routes(for: stored)
        guard candidates.count > 1 else { return EmbyAPIClient(baseURL: candidates.first ?? stored.serverURL, accessToken: token, userId: stored.user.id, serverName: stored.serverName) }

        let winner: URL? = await withTaskGroup(of: URL?.self) { group in
            for url in candidates {
                group.addTask {
                    do {
                        let info = try await EmbyAPIClient(baseURL: url).publicInfo()
                        return info.id == stored.serverId ? url : nil
                    } catch {
                        return nil
                    }
                }
            }
            for await candidate in group {
                if let candidate {
                    group.cancelAll()
                    return candidate
                }
            }
            return nil
        }
        guard let winner else { throw SessionStoreError.noAvailableRoute }
        DiagnosticsLogger.shared.log("Session", "Route selected server=\(stored.serverName) route=\(SensitiveRedactor.redact(url: winner) ?? winner.absoluteString)")
        return EmbyAPIClient(baseURL: winner, accessToken: token, userId: stored.user.id, serverName: stored.serverName)
    }

    func remove(_ stored: EmbySession) async {
        if KeychainStore.get(account: stored.tokenAccount) != nil, let client = try? await clientForBestRoute(for: stored) {
            await client.logout()
        }
        KeychainStore.remove(account: stored.tokenAccount)
        sessions.removeAll { $0.id == stored.id }
        configurations.removeValue(forKey: stored.id)
        if autoStartSessionID == stored.id { autoStartSessionID = nil }
        if session?.id == stored.id { session = nil }
        persistSessions()
        DiagnosticsLogger.shared.log("Session", "Server removed server=\(stored.serverName) user=\(stored.user.name)")
    }

    func logout() async {
        guard let session else { return }
        await remove(session)
    }

    private func normalizedRoutes(_ inputs: [String]) throws -> [URL] {
        var routes: [URL] = []
        var seen = Set<String>()
        for input in inputs {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let url = try normalizedServerURL(trimmed)
            if seen.insert(url.absoluteString).inserted { routes.append(url) }
        }
        guard !routes.isEmpty else { throw EmbyAPIError.invalidServerURL }
        return routes
    }

    private func validatedBestProbe(_ probes: [EmbyRouteProbe], expectedServerId: String?, requiresSharedIdentity: Bool) throws -> EmbyRouteProbe {
        guard !probes.isEmpty else { throw SessionStoreError.noAvailableRoute }
        if let failed = probes.first(where: { !$0.isReachable }) { throw SessionStoreError.routeUnavailable(failed.input) }
        if let expectedServerId, probes.contains(where: { !$0.matchesExpectedServer || $0.serverId != expectedServerId }) { throw SessionStoreError.routeIdentityMismatch }
        if requiresSharedIdentity {
            let ids = probes.compactMap(\.serverId)
            guard ids.count == probes.count, Set(ids).count == 1 else { throw SessionStoreError.routeIdentityMismatch }
        }
        guard let best = probes.filter(\.isReachable).min(by: { ($0.latencyMS ?? Int.max) < ($1.latencyMS ?? Int.max) }) else { throw SessionStoreError.noAvailableRoute }
        return best
    }

    private func persistSessions() {
        persistLocalState()
        persistSyncedRegistry()
    }

    private func persistLocalState() {
        if let data = try? JSONEncoder().encode(sessions) { UserDefaults.standard.set(data, forKey: sessionsKey) }
        if let data = try? JSONEncoder().encode(configurations) { UserDefaults.standard.set(data, forKey: configurationsKey) }
        if let autoStartSessionID { UserDefaults.standard.set(autoStartSessionID, forKey: autoStartKey) }
        else { UserDefaults.standard.removeObject(forKey: autoStartKey) }
    }

    private func loadConfigurations() -> [String: EmbyServerConfiguration] {
        guard let data = UserDefaults.standard.data(forKey: configurationsKey), let stored = try? JSONDecoder().decode([String: EmbyServerConfiguration].self, from: data) else { return [:] }
        return stored
    }

    private func persistSyncedRegistry() {
        let records = sessions.compactMap { stored -> SyncedServerRecord? in
            guard let configuration = configurations[stored.id], configuration.iCloudSyncEnabled, let token = KeychainStore.get(account: stored.tokenAccount) else { return nil }
            return SyncedServerRecord(session: stored, configuration: configuration, accessToken: token, autoStart: autoStartSessionID == stored.id)
        }
        guard !records.isEmpty else {
            KeychainStore.removeSynchronizable(account: syncedRegistryAccount)
            return
        }
        do {
            let data = try JSONEncoder().encode(records)
            guard let value = String(data: data, encoding: .utf8) else { return }
            try KeychainStore.setSynchronizable(value, account: syncedRegistryAccount)
        } catch {
            DiagnosticsLogger.shared.log("Session", "iCloud sync save failed: \(error.localizedDescription)")
        }
    }

    private func mergeSyncedSessions(into restored: inout [EmbySession]) {
        guard let value = KeychainStore.getSynchronizable(account: syncedRegistryAccount), let data = value.data(using: .utf8), let records = try? JSONDecoder().decode([SyncedServerRecord].self, from: data) else { return }
        for record in records where record.configuration.iCloudSyncEnabled {
            let localConfiguration = configurations[record.session.id]
            if let localConfiguration, localConfiguration.updatedAt > record.configuration.updatedAt { continue }
            do { try KeychainStore.set(record.accessToken, account: record.session.tokenAccount) }
            catch {
                DiagnosticsLogger.shared.log("Session", "iCloud token restore failed server=\(record.session.serverName): \(error.localizedDescription)")
                continue
            }
            if let index = restored.firstIndex(where: { $0.id == record.session.id }) { restored[index] = record.session }
            else { restored.append(record.session) }
            configurations[record.session.id] = record.configuration
            if record.autoStart { autoStartSessionID = record.session.id }
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

    private struct SyncedServerRecord: Codable {
        let session: EmbySession
        let configuration: EmbyServerConfiguration
        let accessToken: String
        let autoStart: Bool
    }

    private enum SessionStoreError: LocalizedError {
        case noAvailableRoute
        case routeUnavailable(String)
        case routeIdentityMismatch

        var errorDescription: String? {
            switch self {
            case .noAvailableRoute: return "没有可用的 Emby 线路"
            case .routeUnavailable(let route): return "线路不可用：\(route)"
            case .routeIdentityMismatch: return "聚合线路必须指向同一个 Emby 服务器"
            }
        }
    }
}
