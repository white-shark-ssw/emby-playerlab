import SwiftUI

struct ServerListView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var showingAddServer = false
    @State private var selectedSession: EmbySession?

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
                                .onTapGesture {
                                    sessionStore.activate(stored)
                                    selectedSession = stored
                                }
                                .contextMenu {
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
            AddServerView()
                .environmentObject(sessionStore)
        }
        .fullScreenCover(item: $selectedSession, onDismiss: { sessionStore.leaveServer() }) { stored in
            EmbyServerRootViewV2(session: stored)
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

private struct AddServerView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.presentationMode) private var presentationMode
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Emby 服务器")) {
                    TextField("https://example.com", text: $server)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("密码", text: $password)
                }

                if let error = sessionStore.errorMessage {
                    Section(header: Text("连接失败")) {
                        Text(error).foregroundColor(.red)
                    }
                }

                Section {
                    Text("只保存服务器入口、用户和 AccessToken。密码不会写入本地存储，AccessToken 保存到 Keychain。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("添加服务器")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await sessionStore.addServer(serverText: server, username: username, password: password) != nil {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    } label: {
                        if sessionStore.isWorking { ProgressView() } else { Text("连接") }
                    }
                    .disabled(sessionStore.isWorking || server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || username.isEmpty)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
