import SwiftUI

@main
struct GameApp: App {
    var body: some Scene { WindowGroup { HomeView() } }
}

enum Level: Int, CaseIterable, Identifiable {
    case colors = 1, memory, counting, attention, pattern
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .colors: return "Найди красные предметы"
        case .memory: return "Тренируем память"
        case .counting: return "Посчитай яблоки"
        case .attention: return "Найди лишнее"
        case .pattern: return "Продолжи ряд"
        }
    }
    var icon: String {
        ["🎨","🧠","🔢","👀","🧩"][rawValue - 1]
    }
}

struct HomeView: View {
    @State private var selected: Level?
    @State private var unlocked = 1

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.cyan.opacity(0.2), .blue.opacity(0.08)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        Text("🐻").font(.system(size: 90))
                        Text("Мир Мишки")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                        Text("Играй, учись и исследуй!")
                            .font(.title3).foregroundStyle(.secondary)

                        ForEach(Level.allCases) { level in
                            Button {
                                if level.rawValue <= unlocked { selected = level }
                            } label: {
                                HStack {
                                    Text(level.icon).font(.system(size: 38))
                                    VStack(alignment: .leading) {
                                        Text("Уровень \(level.rawValue)")
                                            .font(.caption.bold())
                                        Text(level.title).font(.headline)
                                    }
                                    Spacer()
                                    Text(level.rawValue <= unlocked ? "▶️" : "🔒")
                                }
                                .padding(18)
                                .frame(maxWidth: .infinity)
                                .background(.white.opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                                .shadow(radius: 4)
                            }
                            .buttonStyle(.plain)
                            .opacity(level.rawValue <= unlocked ? 1 : 0.5)
                        }
                    }
                    .padding()
                }
            }
            .fullScreenCover(item: $selected) { level in
                LevelView(level: level) {
                    unlocked = max(unlocked, min(5, level.rawValue + 1))
                    selected = nil
                }
            }
        }
    }
}

struct LevelView: View {
    let level: Level
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var done = false
    @State private var score = 0
    @State private var found = Set<Int>()

    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.16), .mint.opacity(0.12)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    Button("✕") { dismiss() }
                    Spacer()
                    Text("⭐️ \(score)").bold()
                }
                Text("🐻").font(.system(size: 62))
                Text(prompt).font(.title2.bold()).multilineTextAlignment(.center)
                content
                Spacer()
            }
            .padding()
            if done { SuccessView(onComplete: onComplete) }
        }
    }

    private var prompt: String {
        switch level {
        case .colors: return "Найди все красные предметы!"
        case .memory: return "Найди три картинки, которые были показаны!"
        case .counting: return "Сколько яблок?"
        case .attention: return "Найди предмет, который отличается!"
        case .pattern: return "Что должно быть дальше?"
        }
    }

    @ViewBuilder private var content: some View {
        switch level {
        case .colors:
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                let items = ["🍎","🎈","⭐️","🍓","🟢","🍒","🔵"]
                ForEach(items.indices, id: \.self) { i in
                    Button {
                        if ["🍎","🍓","🍒"].contains(items[i]) {
                            found.insert(i); score += 1
                            if found.count == 3 { finish() }
                        }
                    } label: {
                        Text(items[i]).font(.system(size: 60))
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .background(.white.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                    .opacity(found.contains(i) ? 0.15 : 1)
                }
            }

        case .memory:
            VStack(spacing: 22) {
                Text("🐶   🍎   🚗").font(.system(size: 48))
                Text("Выбери эти картинки:")
                HStack {
                    memoryButton("🐶", correct: true)
                    memoryButton("🍎", correct: true)
                    memoryButton("🚗", correct: true)
                }
                HStack {
                    memoryButton("🐱", correct: false)
                    memoryButton("⭐️", correct: false)
                    memoryButton("🍋", correct: false)
                }
            }

        case .counting:
            VStack(spacing: 24) {
                Text("🍎 🍎 🍎 🍎 🍎").font(.system(size: 42))
                HStack {
                    numberButton(3)
                    numberButton(5)
                    numberButton(7)
                }
            }

        case .attention:
            HStack {
                ForEach(0..<5, id: \.self) { i in
                    Button {
                        if i == 3 { score = 4; finish() }
                    } label: {
                        Text(i == 3 ? "🌙" : "⭐️").font(.system(size: 42))
                    }
                }
            }

        case .pattern:
            VStack(spacing: 24) {
                Text("🔴 🔵 🔴 🔵 ❓").font(.system(size: 36))
                HStack {
                    patternButton("🔴", false)
                    patternButton("🔵", true)
                    patternButton("🟢", false)
                }
            }
        }
    }

    private func memoryButton(_ item: String, correct: Bool) -> some View {
        Button {
            if correct {
                score += 1
                if score == 3 { finish() }
            }
        } label: {
            Text(item).font(.system(size: 42))
                .frame(width: 78, height: 78)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func numberButton(_ n: Int) -> some View {
        Button {
            if n == 5 { score = 3; finish() }
        } label: {
            Text("\(n)").font(.system(size: 32, weight: .heavy))
                .frame(maxWidth: .infinity, minHeight: 78)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func patternButton(_ item: String, _ correct: Bool) -> some View {
        Button { if correct { score = 5; finish() } } label: {
            Text(item).font(.system(size: 42))
                .frame(width: 82, height: 82)
                .background(.white).clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func finish() {
        withAnimation(.spring()) { done = true }
    }
}

struct SuccessView: View {
    let onComplete: () -> Void
    var body: some View {
        Color.black.opacity(0.25).ignoresSafeArea().overlay {
            VStack(spacing: 16) {
                Text("🎉").font(.system(size: 75))
                Text("Молодец!").font(.largeTitle.bold())
                Text("Уровень пройден").font(.title3)
                Text("⭐️ ⭐️ ⭐️").font(.system(size: 32))
                Button("Следующий уровень", action: onComplete)
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: 280).padding()
                    .background(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding(30)
            .frame(maxWidth: 350)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .shadow(radius: 20)
        }
    }
}
