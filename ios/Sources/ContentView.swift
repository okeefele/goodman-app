import SwiftUI

let gmAccent = Color(red: 0.486, green: 0.227, blue: 0.929) // #7C3AED

struct Server: Identifiable {
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

struct ContentView: View {
    @State private var showSettings = false
    @State private var showAbout = false

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.07).ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 14) {
                        connectButton
                        Text("Чтобы подключиться, нажмите на кнопку")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        actionsRow
                        subscriptionCard
                        serverList
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                }
            }
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
                Image(systemName: "gearshape").font(.system(size: 22)).foregroundColor(.white)
            }
            Spacer()
            Menu {
                Button { } label: { Label("VPN из QR", systemImage: "qrcode") }
                Button { } label: { Label("VPN из буфера обмена", systemImage: "doc.on.clipboard") }
                Button { } label: { Label("Перезапуск службы", systemImage: "arrow.clockwise") }
                Button(role: .destructive) { } label: { Label("Удалить профили", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 22)).foregroundColor(.white)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
    }

    private var connectButton: some View {
        Button { } label: {
            ZStack {
                Circle().fill(Color.gray.opacity(0.55)).frame(width: 150, height: 150)
                Image(systemName: "power").font(.system(size: 56, weight: .bold)).foregroundColor(.white)
            }
        }
        .padding(.top, 8)
    }

    private var actionsRow: some View {
        HStack(spacing: 0) {
            actionItem("🔄", "Обновить")
            actionItem("📱", "Мимо VPN")
            actionItem("📊", "Скорость")
            actionItem("🛡", "Kill switch")
        }
    }

    private func actionItem(_ icon: String, _ title: String) -> some View {
        Button { } label: {
            Text("\(icon) \(title)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(gmAccent)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
    }

    private var subscriptionCard: some View {
        VStack(spacing: 5) {
            Text("🆔 1193 2596 0559 6700").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
            Text("📅 Подписка до 05.07.2026").font(.system(size: 12)).foregroundColor(.white.opacity(0.9))
            Text("📱 Устройства: 1 из 1").font(.system(size: 12)).foregroundColor(.white.opacity(0.9))
            Text("⚡ Plus: 0,0 / 10,0 ГБ").font(.system(size: 12)).foregroundColor(.white.opacity(0.9))
            Text("ℹ️ Трафик расходуется только на Plus (белые списки)")
                .font(.system(size: 11)).foregroundColor(.gray).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(gmAccent.opacity(0.16)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gmAccent.opacity(0.5), lineWidth: 1))
    }

    private var serverList: some View {
        VStack(spacing: 0) {
            ForEach(gmServers) { s in
                HStack(spacing: 0) {
                    Text(s.flag).font(.system(size: 20)).frame(width: 40)
                    Text(s.name).font(.system(size: 17)).foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .padding(.vertical, 14).contentShape(Rectangle())
                Divider().background(Color.white.opacity(0.08))
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dark = true

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.07).ignoresSafeArea()
                VStack(spacing: 0) {
                    // Шапка-логотип
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(gmAccent.opacity(0.25)).frame(width: 96, height: 96)
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 46)).foregroundColor(gmAccent)
                        }
                        Text("GoodMan Net").font(.system(size: 22, weight: .light)).foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                    .background(LinearGradient(colors: [Color(red:0.09,green:0.07,blue:0.18), .black],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))

                    List {
                        row("person.crop.circle", "Личный кабинет")
                        row("paperplane", "Telegram")
                        row("doc.text", "Логи событий")
                        Toggle(isOn: $dark) { Label("Тёмная тема", systemImage: "moon.stars") }
                            .tint(gmAccent).listRowBackground(Color.white.opacity(0.05))
                        row("arrow.down.circle", "Обновить приложение")
                        row("info.circle", "О приложении")
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }.tint(gmAccent)
                }
            }
        }
    }

    private func row(_ icon: String, _ title: String) -> some View {
        Label(title, systemImage: icon)
            .foregroundColor(.white)
            .listRowBackground(Color.white.opacity(0.05))
    }
}
