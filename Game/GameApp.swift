import SwiftUI
import AudioToolbox

@main
struct GameApp: App {
    var body: some Scene { WindowGroup { HomeView() } }
}

enum GameSound {
    static func tap() {
        AudioServicesPlaySystemSound(1104)
    }

    static func correct() {
        AudioServicesPlaySystemSound(1057)
    }

    static func wrong() {
        AudioServicesPlaySystemSound(1073)
    }

    static func success() {
        AudioServicesPlaySystemSound(1025)
    }
}

enum Level: Int, CaseIterable, Identifiable {
    case colors = 1, memory, counting, attention, pattern

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .colors: return "Найди красные фрукты"
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
                                if level.rawValue <= unlocked {
                                    GameSound.tap()
                                    selected = level
                                }
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
    @State private var wrong = Set<Int>()
    @State private var memoryOptions: [String] = []
    @State private var memoryCorrect: Set<String> = []
    @State private var memoryFound = Set<String>()

    private let memoryTargets = ["🐶", "🍎", "🚗", "🌈"]
    private let memoryDistractors = ["🐱", "⭐️", "🍋", "🚲", "🦋", "🍉", "🎈", "🐰"]

    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.16), .mint.opacity(0.12)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Button("✕") {
                        GameSound.tap()
                        dismiss()
                    }
                    Spacer()
                    Text("⭐️ \(score)").bold()
                }

                Text("🐻").font(.system(size: 62))
                Text(prompt)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                content
                Spacer()
            }
            .padding()

            if done {
                SuccessView(onComplete: onComplete)
            }
        }
        .onAppear {
            prepareMemoryLevel()
        }
    }

    private var prompt: String {
        switch level {
        case .colors: return "Найди все красные фрукты!"
        case .memory: return "Запомни картинки и найди их среди других!"
        case .counting: return "Сколько яблок?"
        case .attention: return "Найди предмет, который отличается!"
        case .pattern: return "Что должно быть дальше?"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch level {
        case .colors:
            colorsLevel

        case .memory:
            memoryLevel

        case .counting:
            countingLevel

        case .attention:
            HStack {
                ForEach(0..<5, id: \.self) { i in
                    Button {
                        GameSound.tap()
                        if i == 3 {
                            score = 4
                            GameSound.correct()
                            finish()
                        } else {
                            GameSound.wrong()
                        }
                    } label: {
                        Text(i == 3 ? "🌙" : "⭐️")
                            .font(.system(size: 42))
                            .frame(width: 58, height: 70)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }

        case .pattern:
            VStack(spacing: 24) {
                Text("🔴 🔵 🔴 🔵 ❓")
                    .font(.system(size: 36))

                HStack {
                    patternButton("🔴", false)
                    patternButton("🔵", true)
                    patternButton("🟢", false)
                }
            }
        }
    }

    private var colorsLevel: some View {
        let fruits = ["🍎", "🍓", "🍒", "🍌", "🍊", "🍋", "🥝", "🍇"]
        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 14
        ) {
            ForEach(fruits.indices, id: \.self) { i in
                let fruit = fruits[i]
                let isCorrect = ["🍎", "🍓", "🍒"].contains(fruit)

                Button {
                    answerColorFruit(index: i, correct: isCorrect)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(.white.opacity(0.96))

                        Text(fruit)
                            .font(.system(size: 58))

                        if found.contains(i) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.green)
                                .background(Circle().fill(.white).padding(-2))
                                .transition(.scale.combined(with: .opacity))
                        } else if wrong.contains(i) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.red)
                                .background(Circle().fill(.white).padding(-2))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 105)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                found.contains(i) ? .green :
                                wrong.contains(i) ? .red : .clear,
                                lineWidth: 5
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(found.contains(i) || wrong.contains(i))
                .opacity(found.contains(i) || wrong.contains(i) ? 0.72 : 1)
            }
        }
    }

    private func answerColorFruit(index: Int, correct: Bool) {
        guard !found.contains(index), !wrong.contains(index) else { return }

        GameSound.tap()

        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            if correct {
                found.insert(index)
                score += 1
            } else {
                wrong.insert(index)
            }
        }

        if correct {
            GameSound.correct()
            if found.count == 3 {
                finish()
            }
        } else {
            GameSound.wrong()
        }
    }

    private var memoryLevel: some View {
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                ForEach(memoryTargets, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 40))
                        .frame(width: 68, height: 68)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            Text("Выбери все 4 картинки:")
                .font(.headline)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                ForEach(memoryOptions, id: \.self) { item in
                    Button {
                        answerMemory(item)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.white)

                            Text(item)
                                .font(.system(size: 40))

                            if memoryFound.contains(item) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.system(size: 28, weight: .bold))
                                    .offset(x: 22, y: -22)
                            }
                        }
                        .frame(height: 72)
                    }
                    .buttonStyle(.plain)
                    .disabled(memoryFound.contains(item))
                }
            }
        }
    }

    private func prepareMemoryLevel() {
        guard level == .memory, memoryOptions.isEmpty else { return }
        memoryCorrect = Set(memoryTargets)
        memoryOptions = (memoryTargets + memoryDistractors).shuffled()
    }

    private func answerMemory(_ item: String) {
        guard !memoryFound.contains(item) else { return }

        GameSound.tap()

        if memoryCorrect.contains(item) {
            memoryFound.insert(item)
            score += 1
            GameSound.correct()

            if memoryFound.count == memoryCorrect.count {
                finish()
            }
        } else {
            GameSound.wrong()
        }
    }

    private var countingLevel: some View {
        VStack(spacing: 24) {
            Text("🍎 🍎 🍎 🍎 🍎")
                .font(.system(size: 42))

            Text("Выбери правильный ответ")
                .font(.headline)

            HStack(spacing: 14) {
                numberButton(3)
                numberButton(5)
                numberButton(7)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func numberButton(_ n: Int) -> some View {
        Button {
            GameSound.tap()

            if n == 5 {
                score = 3
                GameSound.correct()
                finish()
            } else {
                GameSound.wrong()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)

                Text("\(n)")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 88, height: 88)
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.black.opacity(0.12), lineWidth: 2)
            }
            .shadow(radius: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ответ \(n)")
    }

    private func patternButton(_ item: String, _ correct: Bool) -> some View {
        Button {
            GameSound.tap()

            if correct {
                score = 5
                GameSound.correct()
                finish()
            } else {
                GameSound.wrong()
            }
        } label: {
            Text(item)
                .font(.system(size: 42))
                .frame(width: 82, height: 82)
                .background(.white)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func finish() {
        guard !done else { return }
        GameSound.success()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            done = true
        }
    }
}

struct SuccessView: View {
    let onComplete: () -> Void

    var body: some View {
        Color.black.opacity(0.25)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 16) {
                    Text("🎉").font(.system(size: 75))
                    Text("Молодец!").font(.largeTitle.bold())
                    Text("Уровень пройден").font(.title3)
                    Text("⭐️ ⭐️ ⭐️").font(.system(size: 32))

                    Button("Следующий уровень") {
                        GameSound.tap()
                        onComplete()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 280)
                    .padding()
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
