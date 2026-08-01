import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Emby 公网入口")) {
                    TextField("https://example.com", text: $server)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("密码", text: $password)
                }

                Section {
                    Button {
                        Task {
                            await sessionStore.login(serverText: server, username: username, password: password)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if sessionStore.isWorking {
                                ProgressView()
                            } else {
                                Text("登录")
                            }
                            Spacer()
                        }
                    }
                    .disabled(sessionStore.isWorking || server.isEmpty || username.isEmpty)
                }

                if let error = sessionStore.errorMessage {
                    Section(header: Text("错误")) {
                        Text(error).foregroundColor(.red)
                    }
                }

                Section(header: Text("说明")) {
                    Text("只保存公网 HTTPS 入口，不保存 NAS 的动态 IPv4 或 STUN 端口。密码不落盘，AccessToken 保存到 Keychain。")
                        .font(.footnote)
                }
            }
            .navigationTitle("Emby 播放实验室")
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
