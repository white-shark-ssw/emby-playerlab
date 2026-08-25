from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one match, found {count}: {old[:80]!r}")
    file.write_text(text.replace(old, new, 1))


ui = "Sources/UI/ServerListView.swift"
replace_once(
    ui,
    '''            ServerEditorView(\n                editingSession: stored,\n                initialRoutes: sessionStore.routes(for: stored),\n                initialAutoStart: sessionStore.isAutoStart(stored),\n                initialICloudSync: sessionStore.iCloudSyncEnabled(for: stored)\n            )''',
    '''            ServerEditorView(\n                editingSession: stored,\n                initialRoutes: sessionStore.routes(for: stored),\n                initialAutoStart: sessionStore.isAutoStart(stored),\n                initialICloudSync: sessionStore.iCloudSyncEnabled(for: stored),\n                initialPassword: sessionStore.password(for: stored)\n            )''',
)
replace_once(
    ui,
    '''    let editingSession: EmbySession?\n    @State private var server: String\n    @State private var username: String\n    @State private var password = ""''',
    '''    let editingSession: EmbySession?\n    let initialPassword: String?\n    @State private var server: String\n    @State private var username: String\n    @State private var password: String''',
)
replace_once(
    ui,
    '''    init(editingSession: EmbySession? = nil, initialRoutes: [URL] = [], initialAutoStart: Bool = false, initialICloudSync: Bool = true) {\n        self.editingSession = editingSession\n        let routes = initialRoutes.isEmpty ? editingSession.map { [$0.serverURL] } ?? [] : initialRoutes\n        _server = State(initialValue: routes.first?.absoluteString ?? "")\n        _username = State(initialValue: editingSession?.user.name ?? "")\n        _additionalRoutes = State(initialValue: routes.dropFirst().map(\\.absoluteString))\n        _autoStart = State(initialValue: initialAutoStart)\n        _iCloudSync = State(initialValue: editingSession == nil ? true : initialICloudSync)\n    }''',
    '''    init(editingSession: EmbySession? = nil, initialRoutes: [URL] = [], initialAutoStart: Bool = false, initialICloudSync: Bool = true, initialPassword: String? = nil) {\n        self.editingSession = editingSession\n        self.initialPassword = initialPassword\n        let routes = initialRoutes.isEmpty ? editingSession.map { [$0.serverURL] } ?? [] : initialRoutes\n        _server = State(initialValue: routes.first?.absoluteString ?? "")\n        _username = State(initialValue: editingSession?.user.name ?? "")\n        _password = State(initialValue: initialPassword ?? "")\n        _additionalRoutes = State(initialValue: routes.dropFirst().map(\\.absoluteString))\n        _autoStart = State(initialValue: initialAutoStart)\n        _iCloudSync = State(initialValue: editingSession == nil ? true : initialICloudSync)\n    }''',
)
replace_once(
    ui,
    '''    private func submit() async {\n        if let editingSession {\n            if await sessionStore.updateServer(editingSession, serverTexts: allRouteTexts, password: password, autoStart: autoStart, iCloudSync: iCloudSync) != nil {\n                presentationMode.wrappedValue.dismiss()\n            }\n        } else if await sessionStore.addServer(serverText: server, username: username, password: password, additionalServerTexts: additionalRoutes, autoStart: autoStart, iCloudSync: iCloudSync) != nil {\n            presentationMode.wrappedValue.dismiss()\n        }\n    }''',
    '''    private func submit() async {\n        if let editingSession {\n            let passwordUpdate: String?\n            if let initialPassword { passwordUpdate = password == initialPassword ? nil : password }\n            else { passwordUpdate = password.isEmpty ? nil : password }\n            if await sessionStore.updateServer(editingSession, serverTexts: allRouteTexts, password: passwordUpdate, autoStart: autoStart, iCloudSync: iCloudSync) != nil {\n                presentationMode.wrappedValue.dismiss()\n            }\n        } else if await sessionStore.addServer(serverText: server, username: username, password: password, additionalServerTexts: additionalRoutes, autoStart: autoStart, iCloudSync: iCloudSync) != nil {\n            presentationMode.wrappedValue.dismiss()\n        }\n    }''',
)

session = "Sources/Session/SessionStore.swift"
replace_once(
    session,
    '''            let tokenAccount = "\\(serverId):\\(auth.user.id)"\n            try KeychainStore.set(auth.accessToken, account: tokenAccount)''',
    '''            let tokenAccount = "\\(serverId):\\(auth.user.id)"\n            try KeychainStore.set(auth.accessToken, account: tokenAccount)\n            try persistPassword(password, tokenAccount: tokenAccount, iCloudSync: iCloudSync)''',
)
replace_once(
    session,
    '''    func updateServer(_ stored: EmbySession, serverTexts: [String], password: String = "", autoStart: Bool, iCloudSync: Bool) async -> EmbySession? {''',
    '''    func updateServer(_ stored: EmbySession, serverTexts: [String], password: String? = nil, autoStart: Bool, iCloudSync: Bool) async -> EmbySession? {''',
)
replace_once(
    session,
    '''            if !password.isEmpty {\n                let auth = try await EmbyAPIClient(baseURL: baseURL).authenticate(username: stored.user.name, password: password)\n                if let authServerId = auth.serverId, authServerId != stored.serverId { throw SessionStoreError.routeIdentityMismatch }\n                guard auth.user.id == stored.user.id else { throw SessionStoreError.userIdentityMismatch }\n                try KeychainStore.set(auth.accessToken, account: stored.tokenAccount)\n            }''',
    '''            if let password {\n                let auth = try await EmbyAPIClient(baseURL: baseURL).authenticate(username: stored.user.name, password: password)\n                if let authServerId = auth.serverId, authServerId != stored.serverId { throw SessionStoreError.routeIdentityMismatch }\n                guard auth.user.id == stored.user.id else { throw SessionStoreError.userIdentityMismatch }\n                try KeychainStore.set(auth.accessToken, account: stored.tokenAccount)\n                try persistPassword(password, tokenAccount: stored.tokenAccount, iCloudSync: iCloudSync)\n            } else if let existingPassword = password(for: stored) {\n                try persistPassword(existingPassword, tokenAccount: stored.tokenAccount, iCloudSync: iCloudSync)\n            }''',
)
replace_once(
    session,
    '''    func iCloudSyncEnabled(for stored: EmbySession) -> Bool { configurations[stored.id]?.iCloudSyncEnabled ?? false }\n\n    func probeServerRoutes''',
    '''    func iCloudSyncEnabled(for stored: EmbySession) -> Bool { configurations[stored.id]?.iCloudSyncEnabled ?? false }\n\n    func password(for stored: EmbySession) -> String? {\n        KeychainStore.get(account: passwordAccount(stored.tokenAccount)) ?? KeychainStore.getSynchronizable(account: syncedPasswordAccount(stored.tokenAccount))\n    }\n\n    func probeServerRoutes''',
)
replace_once(
    session,
    '''        KeychainStore.remove(account: stored.tokenAccount)\n        sessions.removeAll { $0.id == stored.id }''',
    '''        KeychainStore.remove(account: stored.tokenAccount)\n        removePassword(tokenAccount: stored.tokenAccount)\n        sessions.removeAll { $0.id == stored.id }''',
)
replace_once(
    session,
    '''    private func persistSessions() {\n        persistLocalState()\n        persistSyncedRegistry()\n    }''',
    '''    private func passwordAccount(_ tokenAccount: String) -> String { "OnePlayer.ServerPassword.\\(tokenAccount)" }\n\n    private func syncedPasswordAccount(_ tokenAccount: String) -> String { "OnePlayer.SyncedServerPassword.\\(tokenAccount)" }\n\n    private func persistPassword(_ password: String, tokenAccount: String, iCloudSync: Bool) throws {\n        try KeychainStore.set(password, account: passwordAccount(tokenAccount))\n        if iCloudSync { try KeychainStore.setSynchronizable(password, account: syncedPasswordAccount(tokenAccount)) }\n        else { KeychainStore.removeSynchronizable(account: syncedPasswordAccount(tokenAccount)) }\n    }\n\n    private func removePassword(tokenAccount: String) {\n        KeychainStore.remove(account: passwordAccount(tokenAccount))\n        KeychainStore.removeSynchronizable(account: syncedPasswordAccount(tokenAccount))\n    }\n\n    private func persistSessions() {\n        persistLocalState()\n        persistSyncedRegistry()\n    }''',
)

print("Add Emby password retention + iCloud Keychain sync patch applied")
