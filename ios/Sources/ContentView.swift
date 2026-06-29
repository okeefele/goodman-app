import SwiftUI

let gmAccent = Color(red: 0.486, green: 0.227, blue: 0.929) // #7C3AED

struct Server: Identifiable, Equatable {
    let id = UUID()
    let flag: String
    let name: String
}

let gmServers: [Server] = [
    .init(flag: "🇬🇧", name: "GoodMan Net"),
    .init(flag: "🇬🇧", name: "GoodMan Net Plus (белые списки)"),
    .init(flag: "📺", name: "GoodMan YouTube без рекламы"),
    .init(flag: "🇩🇪", name: "GoodMan Германия"),
    .init(flag: "🇵🇱", name: "GoodMan Польша"),
    .init(flag: "🇮🇹", name: "GoodMan Италия"),
    .init(flag: "🇨🇦", name: "GoodMan Канада"),
    .init(flag: "🇺🇸", name: "GoodMan США")
]

enum ConnState { case off, connecting, on }

struct ContentView: View {
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var conn: ConnState = .off
    @State private var selected: Server.ID = gmServers.first!.id
    @State private var toast: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 14) {
                        connectButton
                        statusText
                        actionsRow
                        subscriptionCard
                        serverList
                    }
                    .padding(.horizontal, 14).padding(.top, 8)
                }
            }
            if let t = toast { toastView(t) }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .alert("GoodMan Net", isPresented: $showAbout) {
            Button("Закрыть", role: .cancel) {}
        } message: {
            Text("Быстрый VPN на протоколе VLESS / Reality.\n\nВерсия: 0.1 (iOS)\nСайт: gdman.ink\nTelegram: @goodmanNet_bot")
        }
    }

    private var topBar: some View {
        HStack {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").font(.system(size: 22)).foregroundColor(.primary)
            }
            Spacer()
            Menu {
                Button { flash("Импорт из QR (демо)") } label: { Label("VPN из QR", systemImage: "qrcode") }
                Button { flash("Импорт из буфера (демо)") } label: { Label("VPN из буфера обмена", systemImage: "doc.on.clipboard") }
                Button { flash("Служба перезапущена (демо)") } label: { Label("Перезапуск службы", systemImage: "arrow.clockwise") }
                Button(role: .destructive) { flash("Профили удалены (демо)") } label: { Label("Удалить профили", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 22)).foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
    }

    private var connectColor: Color {
        switch conn { case .off: return .gray.opacity(0.55); case .connecting: return .orange; case .on: return .green }
    }

    private var connectButton: some View {
        Button { toggleConnect() } label: {
            ZStack {
                Circle().fill(connectColor).frame(width: 150, height: 150)
                if conn == .connecting {
                    ProgressView().scaleEffect(1.6).tint(.white)
                } else {
                    Image(systemName: "power").font(.system(size: 56, weight: .bold)).foregroundColor(.white)
                }
            }
        }
        .padding(.top, 8)
        .animation(.easeInOut, value: conn)
    }

    private var statusText: some View {
        let name = gmServers.first { $0.id == selected }?.name ?? ""
        let txt: String
        switch conn {
        case .off: txt = "Чтобы подключиться, нажмите на кнопку"
        case .connecting: txt = "Подключение…"
        case .on: txt = "✅ \(name) — подключено"
        }
        return Text(txt).font(.system(size: 15, weight: .bold))
            .foregroundColor(.primary).multilineTextAlignment(.center)
    }

    private func toggleConnect() {
        switch conn {
        case .off:
            conn = .connecting
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if conn == .connecting { conn = .on }
            }
        case .connecting, .on:
            conn = .off
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 0) {
            actionItem("🔄", "Обновить") { flash("Подписка обновлена (демо)") }
            actionItem("📱", "Мимо VPN") { flash("Приложения мимо VPN (демо)") }
            actionItem("📊", "Скорость") { flash(conn == .on ? "Пинг: 42 ms (демо)" : "Сначала подключитесь") }
            actionItem("🛡", "Kill switch") { flash("Kill switch: включается в настройках VPN") }
        }
    }

    private func actionItem(_ icon: String, _ title: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text("\(icon) \(title)")
                .font(.system(size: 11, weight: .bold)).foregroundColor(gmAccent)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity).padding(.vertical, 8).contentShape(Rectangle())
        }
    }

    private var subscriptionCard: some View {
        VStack(spacing: 5) {
            Text("🆔 1193 2596 0559 6700").font(.system(size: 13, weight: .bold)).foregroundColor(.primary)
            Text("📅 Подписка до 05.07.2026").font(.system(size: 12)).foregroundColor(.primary.opacity(0.85))
            Text("📱 Устройства: 1 из 1").font(.system(size: 12)).foregroundColor(.primary.opacity(0.85))
            Text("⚡ Plus: 0,0 / 10,0 ГБ").font(.system(size: 12)).foregroundColor(.primary.opacity(0.85))
            Text("ℹ️ Трафик расходуется только на Plus (белые списки)")
                .font(.system(size: 11)).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(gmAccent.opacity(0.16)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gmAccent.opacity(0.5), lineWidth: 1))
    }

    private var serverList: some View {
        VStack(spacing: 0) {
            ForEach(gmServers) { s in
                Button { selected = s.id } label: {
                    HStack(spacing: 0) {
                        Text(s.flag).font(.system(size: 20)).frame(width: 40)
                        Text(s.name).font(.system(size: 17)).foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Image(systemName: selected == s.id ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selected == s.id ? gmAccent : .secondary.opacity(0.4))
                            .frame(width: 34)
                    }
                    .padding(.vertical, 14)
                    .background(selected == s.id ? gmAccent.opacity(0.10) : .clear)
                    .contentShape(Rectangle())
                }
                Divider()
            }
        }
    }

    private func flash(_ msg: String) {
        toast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { if toast == msg { toast = nil } }
    }

    private func toastView(_ t: String) -> some View {
        Text(t).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Capsule().fill(Color.black.opacity(0.85)))
            .padding(.bottom, 40).transition(.opacity)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("gm_dark") private var dark = true
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(gmAccent.opacity(0.25)).frame(width: 96, height: 96)
                            Image(systemName: "shield.lefthalf.filled").font(.system(size: 46)).foregroundColor(gmAccent)
                        }
                        Text("GoodMan Net").font(.system(size: 22, weight: .light)).foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                    .background(LinearGradient(colors: [Color(red:0.09,green:0.07,blue:0.18), .black],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))

                    List {
                        link("person.crop.circle", "Личный кабинет")
                        link("paperplane", "Telegram")
                        link("doc.text", "Логи событий")
                        Toggle(isOn: $dark) { Label("Тёмная тема", systemImage: "moon.stars") }
                            .tint(gmAccent).listRowBackground(Color.secondary.opacity(0.12))
                        link("arrow.down.circle", "Обновить приложение")
                        Button { showAbout = true } label: {
                            Label("О приложении", systemImage: "info.circle").foregroundColor(.primary)
                        }.listRowBackground(Color.secondary.opacity(0.12))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Закрыть") { dismiss() }.tint(gmAccent) } }
            .alert("GoodMan Net", isPresented: $showAbout) {
                Button("Закрыть", role: .cancel) {}
            } message: {
                Text("Быстрый VPN на VLESS / Reality.\nВерсия 0.1 (iOS)\ngdman.ink · @goodmanNet_bot")
            }
        }
    }

    private func link(_ icon: String, _ title: String) -> some View {
        Label(title, systemImage: icon).foregroundColor(.primary)
            .listRowBackground(Color.secondary.opacity(0.12))
    }
}
