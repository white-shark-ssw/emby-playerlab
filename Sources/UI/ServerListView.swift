import SwiftUI

struct ServerListView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var showingAddServer = false
    @State private var editingSession: EmbySession?
    let onOpenServer: (EmbySession) -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    Button { showingAddServer = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .light))
                    }
                    Button {} label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 40, height: 40)
                    }
                }

                Text("服务器")
                    .font(.largeTitle.weight(.bold))

                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)
                    TextField("搜索服务器", text: $searchText)
                        .font(.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 13)
                .frame(height: 44)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                if filteredSessions.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredSessions) { stored in
                            serverCard(stored)
                                .onTapGesture { onOpenServer(stored) }
                                .contextMenu {
                                    Button { editingSession = stored } label: {
                                        Label("编辑", systemImage: "pencil")
                                    }
                                    Button {
                                        UIPasteboard.general.string = stored.serverURL.absoluteString
                                    } label: {
                                        Label("复制地址", systemImage: "doc.on.doc")
                                    }
                                    Button(role: .destructive) {
                                        Task { await sessionStore.remove(stored) }
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .sheet(isPresented: $showingAddServer) {
            ServerEditorView()
                .environmentObject(sessionStore)
        }
        .sheet(item: $editingSession) { stored in
            ServerEditorView(
                editingSession: stored,
                initialRoutes: sessionStore.routes(for: stored),
                initialAutoStart: sessionStore.isAutoStart(stored),
                initialICloudSync: sessionStore.iCloudSyncEnabled(for: stored),
                initialPassword: sessionStore.password(for: stored)
            )
            .environmentObject(sessionStore)
        }
    }

    private var filteredSessions: [EmbySession] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return sessionStore.sessions }
        return sessionStore.sessions.filter {
            $0.serverName.localizedCaseInsensitiveContains(term) || $0.user.name.localizedCaseInsensitiveContains(term) || $0.serverURL.absoluteString.localizedCaseInsensitiveContains(term)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 38, weight: .light))
                .foregroundColor(.secondary)
            Text("还没有服务器")
                .font(.headline)
            Text("点击右上角 + 添加 Emby 服务器")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func serverCard(_ stored: EmbySession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    Circle().fill(Color.green.opacity(0.8))
                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)
                Spacer()
                Text(stored.serverVersion)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 6) {
                Text(stored.serverName)
                    .font(.headline)
                    .lineLimit(1)
                Circle().fill(Color.green).frame(width: 6, height: 6)
            }

            Spacer(minLength: 2)

            HStack(spacing: 7) {
                Image(systemName: "person")
                Text(stored.user.name)
                    .lineLimit(1)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(Color.green.opacity(colorScheme == .dark ? 0.28 : 0.16))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ServerEditorView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.presentationMode) private var presentationMode
    let editingSession: EmbySession?
    let initialPassword: String?
    @State private var server: String
    @State private var username: String
    @State private var password: String
    @State private var showsPassword = false
    @State private var additionalRoutes: [String]
    @State private var autoStart: Bool
    @State private var iCloudSync: Bool
    @State private var routeProbes: [EmbyRouteProbe] = []
    @State private var isProbing = false

    init(editingSession: EmbySession? = nil, initialRoutes: [URL] = [], initialAutoStart: Bool = false, initialICloudSync: Bool = true, initialPassword: String? = nil) {
        self.editingSession = editingSession
        self.initialPassword = initialPassword
        let routes = initialRoutes.isEmpty ? editingSession.map { [$0.serverURL] } ?? [] : initialRoutes
        _server = State(initialValue: routes.first?.absoluteString ?? "")
        _username = State(initialValue: editingSession?.user.name ?? "")
        _password = State(initialValue: initialPassword ?? "")
        _additionalRoutes = State(initialValue: routes.dropFirst().map(\.absoluteString))
        _autoStart = State(initialValue: initialAutoStart)
        _iCloudSync = State(initialValue: editingSession == nil ? true : initialICloudSync)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    serverInformationCard
                    if editingSession == nil { pasteButton }
                    routeCard
                    settingsCard
                    if let error = sessionStore.errorMessage { errorCard(error) }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(editingSession == nil ? "添加服务器" : "编辑服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if sessionStore.isWorking { ProgressView() }
                        else { Text(editingSession == nil ? "连接" : "保存") }
                    }
                    .disabled(sessionStore.isWorking || server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (editingSession == nil && username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear { sessionStore.errorMessage = nil }
        .task {
            if editingSession != nil { await measureRoutes() }
        }
    }

    private var serverInformationCard: some View {
        VStack(spacing: 0) {
            sectionHeader("服务器")
            editorInputRow(systemImage: "globe", title: "服务器地址") {
                TextField("https://example.com", text: $server)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Divider().padding(.leading, 54)
            editorInputRow(systemImage: "person", title: "用户名") {
                if editingSession == nil {
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    Text(username)
                        .foregroundColor(.primary)
                }
            }
            Divider().padding(.leading, 54)
            editorInputRow(systemImage: "lock", title: "密码") {
                HStack(spacing: 10) {
                    Group {
                        if showsPassword { TextField("密码", text: $password) }
                        else { SecureField("密码", text: $password) }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    Button { showsPassword.toggle() } label: {
                        Image(systemName: showsPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var pasteButton: some View {
        Button(action: pasteClipboard) {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 17, weight: .semibold))
                Text("一键粘贴")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.blue.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var routeCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("多线路聚合")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await measureRoutes() }
                } label: {
                    if isProbing { ProgressView().scaleEffect(0.85) }
                    else { Text("测速").font(.subheadline.weight(.semibold)) }
                }
                .disabled(isProbing || allRouteTexts.isEmpty)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)

            Divider().padding(.leading, 16)
            routeEditorRow(text: $server, removable: false, remove: {})
            ForEach(Array(additionalRoutes.indices), id: \.self) { index in
                Divider().padding(.leading, 54)
                routeEditorRow(text: $additionalRoutes[index], removable: true) {
                    additionalRoutes.remove(at: index)
                }
            }
            Divider().padding(.leading, 16)
            Button {
                additionalRoutes.append("")
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "plus.circle.fill")
                    Text("添加线路")
                    Spacer()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .frame(height: 50)
            }
            .buttonStyle(.plain)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            settingRow(systemImage: "bolt.fill", title: "自动启动", isOn: $autoStart)
            Divider().padding(.leading, 54)
            settingRow(systemImage: "icloud.fill", title: "iCloud 同步", isOn: $iCloudSync)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
    }

    private func editorInputRow<Content: View>(systemImage: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                content()
                    .font(.body)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 68)
    }

    private func routeEditorRow(text: Binding<String>, removable: Bool, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(routeStatusColor(for: text.wrappedValue))
                .frame(width: 8, height: 8)
            TextField("https://example.com", text: text)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline)
            routeStatusView(for: text.wrappedValue)
            if removable {
                Button(action: remove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
    }

    @ViewBuilder
    private func routeStatusView(for text: String) -> some View {
        if let probe = probe(for: text) {
            if !probe.isReachable {
                Text("失败")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red)
            } else if !probe.matchesExpectedServer {
                Text("不匹配")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red)
            } else if let latency = probe.latencyMS {
                HStack(spacing: 5) {
                    Text("\(latency) ms")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                    if fastestRouteInput == probe.input {
                        Text("最快")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }

    private func routeStatusColor(for text: String) -> Color {
        guard let probe = probe(for: text) else { return Color(uiColor: .tertiaryLabel) }
        if !probe.isReachable || !probe.matchesExpectedServer { return .red }
        if fastestRouteInput == probe.input { return .green }
        return .blue
    }

    private func settingRow(systemImage: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 26)
            Text(title)
                .font(.body)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 56)
    }

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .foregroundColor(.red)
        .padding(14)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var allRouteTexts: [String] {
        ([server] + additionalRoutes).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private var fastestRouteInput: String? {
        routeProbes.filter { $0.isReachable && $0.matchesExpectedServer }.min { ($0.latencyMS ?? Int.max) < ($1.latencyMS ?? Int.max) }?.input
    }

    private func probe(for text: String) -> EmbyRouteProbe? {
        let canonical = canonicalRoute(text)
        return routeProbes.first { $0.input == canonical }
    }

    private func canonicalRoute(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return value }
        if !value.contains("://") { value = "https://\(value)" }
        while value.count > 1 && value.hasSuffix("/") { value.removeLast() }
        return value
    }

    private func measureRoutes() async {
        let routes = allRouteTexts.map(canonicalRoute)
        guard !routes.isEmpty else {
            routeProbes = []
            return
        }
        isProbing = true
        let expectedServerId = editingSession?.serverId
        routeProbes = await sessionStore.probeServerRoutes(serverTexts: routes, expectedServerId: expectedServerId)
        isProbing = false
    }

    private func submit() async {
        if let editingSession {
            let passwordUpdate: String?
            if let initialPassword { passwordUpdate = password == initialPassword ? nil : password }
            else { passwordUpdate = password.isEmpty ? nil : password }
            if await sessionStore.updateServer(editingSession, serverTexts: allRouteTexts, password: passwordUpdate, autoStart: autoStart, iCloudSync: iCloudSync) != nil {
                presentationMode.wrappedValue.dismiss()
            }
        } else if await sessionStore.addServer(serverText: server, username: username, password: password, additionalServerTexts: additionalRoutes, autoStart: autoStart, iCloudSync: iCloudSync) != nil {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func pasteClipboard() {
        guard let text = UIPasteboard.general.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let parsed = ClipboardServerCredentials.parse(text)
        if let parsedServer = parsed.server { server = parsedServer }
        if !parsed.additionalRoutes.isEmpty { additionalRoutes = parsed.additionalRoutes }
        if let parsedUsername = parsed.username { username = parsedUsername }
        if let parsedPassword = parsed.password { password = parsedPassword }
    }
}

private struct ClipboardServerCredentials {
    let server: String?
    let additionalRoutes: [String]
    let username: String?
    let password: String?

    static func parse(_ text: String) -> ClipboardServerCredentials {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let serverLabels = ["服务器地址", "服务器", "地址", "server", "url"]
        let routeLabels = ["线路", "route", "line"]
        let usernameLabels = ["用户名", "账号", "账户", "username", "user", "account"]
        let passwordLabels = ["密码", "password", "pass", "pwd"]

        var server = firstLabeledValue(lines, labels: serverLabels)
        var username = firstLabeledValue(lines, labels: usernameLabels)
        var password = firstLabeledValue(lines, labels: passwordLabels)
        var routeCandidates: [String] = []

        for line in lines {
            let lower = line.lowercased()
            if (lower.hasPrefix("http://") || lower.hasPrefix("https://")) && labeledValue(line, labels: usernameLabels + passwordLabels) == nil { routeCandidates.append(line) }
            if let route = labeledValue(line, labels: serverLabels + routeLabels), !route.isEmpty { routeCandidates.append(route) }
        }
        routeCandidates = unique(routeCandidates)

        if server == nil { server = routeCandidates.first }
        if server == nil, let first = lines.first, lines.count >= 3, first.contains(".") && !first.contains(" ") { server = first }

        if username == nil || password == nil {
            if let server, let index = lines.firstIndex(where: { $0 == server || $0.contains(server) }) {
                let tail = Array(lines.dropFirst(index + 1)).filter { labeledValue($0, labels: routeLabels) == nil && !$0.contains("://") }
                if username == nil, !tail.isEmpty { username = tail[0] }
                if password == nil, tail.count > 1 { password = tail[1] }
            }
        }

        let primary = server
        let extras = routeCandidates.filter { candidate in
            guard let primary else { return true }
            return candidate != primary
        }
        return ClipboardServerCredentials(server: primary, additionalRoutes: extras, username: username, password: password)
    }

    private static func firstLabeledValue(_ lines: [String], labels: [String]) -> String? {
        for line in lines {
            if let value = labeledValue(line, labels: labels), !value.isEmpty { return value }
        }
        return nil
    }

    private static func labeledValue(_ line: String, labels: [String]) -> String? {
        let lower = line.lowercased()
        for label in labels {
            let normalizedLabel = label.lowercased()
            guard lower.hasPrefix(normalizedLabel) else { continue }
            var value = String(line.dropFirst(label.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            while let first = value.first, first == ":" || first == "：" || first == "=" || first == "-" {
                value.removeFirst()
                value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return value
        }
        return nil
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
