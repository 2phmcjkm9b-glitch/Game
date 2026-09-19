import SwiftUI
import AVFoundation
import Foundation

@main
struct GameApp: App {
    var body: some Scene { WindowGroup { HomeView() } }
}

enum GameSound {
    static var volume: Float {
        get { Float(UserDefaults.standard.object(forKey: "soundVolume") as? Double ?? 0.55) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "soundVolume") }
    }

    private static var players: [AVAudioPlayer] = []

    static func play(_ notes: [Double], duration: Double = 0.12) {
        guard volume > 0.01 else { return }
        let sampleRate = 44100.0
        let samples = Int(sampleRate * duration)
        var data = Data()
        var header = [UInt8]()
        func append32(_ v: UInt32) { header += [UInt8(v & 255), UInt8((v >> 8) & 255), UInt8((v >> 16) & 255), UInt8((v >> 24) & 255)] }
        func append16(_ v: UInt16) { header += [UInt8(v & 255), UInt8((v >> 8) & 255)] }
        header += Array("RIFF".utf8); append32(UInt32(36 + samples * 2)); header += Array("WAVE".utf8)
        header += Array("fmt ".utf8); append32(16); append16(1); append16(1); append32(UInt32(sampleRate)); append32(UInt32(sampleRate * 2)); append16(2); append16(16)
        header += Array("data".utf8); append32(UInt32(samples * 2))
        data.append(contentsOf: header)
        for i in 0..<samples {
            let t = Double(i) / sampleRate
            let n = notes[Int((Double(i) / Double(samples) * Double(notes.count)).rounded(.down)).clamped(to: 0...(notes.count - 1))]
            let fade = min(1.0, Double(i) / (sampleRate * 0.015)) * min(1.0, Double(samples - i) / (sampleRate * 0.03))
            let sample = Int16(sin(2 * .pi * n * t) * 11000 * Double(volume) * fade)
            data.append(UInt8(sample & 255)); data.append(UInt8((Int(sample) >> 8) & 255))
        }
        do {
            let p = try AVAudioPlayer(data: data)
            p.volume = volume
            p.play()
            players.append(p)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.25) {
                players.removeAll { !$0.isPlaying }
            }
        } catch {}
    }

    static func tap() { play([520], duration: 0.06) }
    static func correct() { play([660, 880], duration: 0.16) }
    static func wrong() { play([260, 190], duration: 0.18) }
    static func success() { play([523, 659, 784, 1047], duration: 0.32) }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}

enum Level: Int, CaseIterable, Identifiable {
    case colors = 1, memory, counting, attention, pattern, size, blue, order, animals, stars
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .colors: return "Найди красные фрукты"
        case .memory: return "Тренируем память"
        case .counting: return "Посчитай яблоки"
        case .attention: return "Найди лишнее"
        case .pattern: return "Продолжи ряд"
        case .size: return "Найди самый большой"
        case .blue: return "Найди синие предметы"
        case .order: return "Нажми по порядку"
        case .animals: return "Найди животных"
        case .stars: return "Собери звёздочки"
        }
    }

    var icon: String {
        ["🎨","🧠","🔢","👀","🧩","📏","🔵","🔢","🐾","⭐️"][rawValue - 1]
    }
}

struct HomeView: View {
    @State private var selected: Level?
    @AppStorage("unlockedLevel") private var unlocked = 1
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.cyan.opacity(0.2), .blue.opacity(0.08)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        Text("🐻").font(.system(size: 80))
                        Text("Мир Мишки").font(.system(size: 34, weight: .heavy, design: .rounded))
                        Text("10 весёлых заданий").font(.headline).foregroundStyle(.secondary)

                        Button { GameSound.tap(); showSettings = true } label: {
                            Label("Настройки звука", systemImage: "speaker.wave.2.fill")
                                .font(.headline).padding(.vertical, 10).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        ForEach(Level.allCases) { level in
                            Button {
                                guard level.rawValue <= unlocked else { return }
                                GameSound.tap(); selected = level
                            } label: {
                                HStack {
                                    Text(level.icon).font(.system(size: 34))
                                    VStack(alignment: .leading) {
                                        Text("Уровень \(level.rawValue)").font(.caption.bold())
                                        Text(level.title).font(.headline)
                                    }
                                    Spacer()
                                    Text(level.rawValue <= unlocked ? "▶️" : "🔒")
                                }
                                .padding(16).frame(maxWidth: .infinity)
                                .background(.white.opacity(0.92))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(radius: 3)
                            }
                            .buttonStyle(.plain)
                            .opacity(level.rawValue <= unlocked ? 1 : 0.5)
                        }
                    }.padding()
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .fullScreenCover(item: $selected) { level in
                LevelView(level: level) {
                    unlocked = max(unlocked, min(Level.allCases.count, level.rawValue + 1))
                    selected = nil
                }
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("soundVolume") private var volume: Double = 0.55

    var body: some View {
        NavigationStack {
            Form {
                Section("Звук") {
                    HStack {
                        Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        Slider(value: $volume, in: 0...1) { _ in GameSound.tap() }
                        Text("\(Int(volume * 100))%").monospacedDigit().frame(width: 50)
                    }
                    Button("Проверить звук") { GameSound.correct() }
                }
                Section("Прогресс") {
                    Text("Открыто уровней: \(max(1, UserDefaults.standard.integer(forKey: "unlockedLevel")))")
                }
            }
            .navigationTitle("Настройки")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
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
    @State private var memoryFound = Set<String>()
    @State private var orderItems: [Int] = []
    @State private var nextNumber = 1

    private let memoryTargets = ["🐶","🍎","🚗","🌈"]
    private let memoryDistractors = ["🐱","⭐️","🍋","🚲","🦋","🍉","🎈","🐰"]

    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.16), .mint.opacity(0.12)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Button("✕") { GameSound.tap(); dismiss() }
                    Spacer()
                    Text("⭐️ \(score)").bold()
                }
                Text("🐻").font(.system(size: 58))
                Text(prompt).font(.title2.bold()).multilineTextAlignment(.center)
                content
                Spacer()
            }.padding()
            if done { SuccessView(onComplete: onComplete) }
        }
        .onAppear { prepare() }
    }

    private var prompt: String {
        switch level {
        case .colors: return "Найди все красные фрукты!"
        case .memory: return "Запомни картинки и найди их среди других!"
        case .counting: return "Сколько яблок?"
        case .attention: return "Найди предмет, который отличается!"
        case .pattern: return "Что должно быть дальше?"
        case .size: return "Нажми на самый большой предмет!"
        case .blue: return "Найди все синие предметы!"
        case .order: return "Нажимай числа от 1 до 5"
        case .animals: return "Найди всех животных!"
        case .stars: return "Собери все звёздочки!"
        }
    }

    @ViewBuilder private var content: some View {
        switch level {
        case .colors: colorsLevel
        case .memory: memoryLevel
        case .counting: countingLevel
        case .attention: oddLevel
        case .pattern: patternLevel
        case .size: sizeLevel
        case .blue: blueLevel
        case .order: orderLevel
        case .animals: animalsLevel
        case .stars: starsLevel
        }
    }

    private func tile(_ text: String, index: Int, correct: Bool, size: CGFloat = 76) -> some View {
        Button {
            guard !found.contains(index) && !wrong.contains(index) else { return }
            GameSound.tap()
            if correct {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) { found.insert(index); score += 1 }
                GameSound.correct()
            } else {
                withAnimation(.easeInOut(duration: 0.12)) { wrong.insert(index) }
                GameSound.wrong()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.white)
                Text(text).font(.system(size: size))
                if found.contains(index) { Text("✓").font(.system(size: 40, weight: .black)).foregroundStyle(.green).background(Circle().fill(.white).padding(-3)).transition(.scale) }
                if wrong.contains(index) { Text("✕").font(.system(size: 40, weight: .black)).foregroundStyle(.red).background(Circle().fill(.white).padding(-3)).transition(.scale) }
            }
            .frame(height: 86)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(found.contains(index) ? .green : wrong.contains(index) ? .red : .clear, lineWidth: 5))
            .scaleEffect(wrong.contains(index) ? 0.94 : 1)
        }.buttonStyle(.plain).disabled(found.contains(index) || wrong.contains(index))
    }

    private var colorsLevel: some View {
        let fruits = ["🍎","🍓","🍒","🍌","🍊","🍋","🥝","🍇"]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(fruits.indices, id: \.self) { i in tile(fruits[i], index: i, correct: i < 3, size: 54) }
        }
        .onChange(of: found) { _, v in if v.count == 3 { finish() } }
    }

    private var memoryLevel: some View {
        VStack(spacing: 14) {
            HStack { ForEach(memoryTargets, id: \.self) { Text($0).font(.system(size: 34)).frame(width: 58, height: 58).background(.white).clipShape(RoundedRectangle(cornerRadius: 14)) } }
            Text("Выбери все 4 картинки").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 10) {
                ForEach(memoryOptions, id: \.self) { item in
                    Button { answerMemory(item) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16).fill(.white)
                            Text(item).font(.system(size: 36))
                            if memoryFound.contains(item) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title2).offset(x: 24,y:-24) }
                        }.frame(height: 66)
                    }.buttonStyle(.plain).disabled(memoryFound.contains(item))
                }
            }
        }
    }

    private func answerMemory(_ item: String) {
        GameSound.tap()
        if memoryTargets.contains(item) {
            memoryFound.insert(item); score += 1; GameSound.correct()
            if memoryFound.count == memoryTargets.count { finish() }
        } else { GameSound.wrong() }
    }

    private var countingLevel: some View {
        VStack(spacing: 20) {
            Text("🍎 🍎 🍎 🍎 🍎").font(.system(size: 42))
            Text("Выбери правильный ответ").font(.headline)
            HStack(spacing: 12) { numberButton(3); numberButton(5); numberButton(7) }
        }
    }

    private func numberButton(_ n: Int) -> some View {
        Button { GameSound.tap(); if n == 5 { score = 3; GameSound.correct(); finish() } else { GameSound.wrong() } } label: {
            Text("\(n)").font(.system(size: 38, weight: .heavy, design: .rounded)).foregroundStyle(.black)
                .frame(width: 88, height: 88).background(.white).clipShape(RoundedRectangle(cornerRadius: 20)).shadow(radius: 3)
        }.buttonStyle(.plain)
    }

    private var oddLevel: some View {
        LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 10) {
            let items = ["⭐️","⭐️","⭐️","🌙","⭐️","⭐️","⭐️","⭐️"]
            ForEach(items.indices, id: \.self) { i in tile(items[i], index: i, correct: i == 3, size: 40) }
        }
        .onChange(of: found) { _, v in if v.contains(3) { finish() } }
    }

    private var patternLevel: some View {
        VStack(spacing: 20) {
            Text("🔴 🔵 🔴 🔵 ❓").font(.system(size: 34))
            HStack { answerPattern("🔴", correct: false); answerPattern("🔵", correct: true); answerPattern("🟢", correct: false) }
        }
    }

    private func answerPattern(_ text: String, correct: Bool) -> some View {
        Button { GameSound.tap(); if correct { score = 5; GameSound.correct(); finish() } else { GameSound.wrong() } } label: {
            Text(text).font(.system(size: 40)).frame(width: 80, height: 80).background(.white).clipShape(Circle())
        }.buttonStyle(.plain)
    }

    private var sizeLevel: some View {
        HStack(alignment: .center, spacing: 8) {
            let sizes: [CGFloat] = [42, 58, 76, 50, 64, 46]
            ForEach(sizes.indices, id: \.self) { i in tile(["🍎","🍊","🍋","🍓","🍐","🍒"][i], index: i, correct: i == 2, size: sizes[i] * 0.72) }
        }.onChange(of: found) { _, v in if v.contains(2) { finish() } }
    }

    private var blueLevel: some View {
        let items = ["🔵","🟢","🔴","🔵","🟡","🟣","🔵","🟠","🔵","🟢"]
        return LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 10) {
            ForEach(items.indices, id: \.self) { i in tile(items[i], index: i, correct: items[i] == "🔵", size: 40) }
        }.onChange(of: found) { _, v in if v.count == 4 { finish() } }
    }

    private var orderLevel: some View {
        LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 12) {
            ForEach(orderItems, id: \.self) { n in
                Button {
                    GameSound.tap()
                    if n == nextNumber {
                        score += 1; GameSound.correct()
                        withAnimation { orderItems.removeAll { $0 == n }; nextNumber += 1 }
                        if nextNumber == 6 { finish() }
                    } else { GameSound.wrong() }
                } label: {
                    Text("\(n)").font(.system(size: 40, weight: .heavy)).foregroundStyle(.black).frame(height: 80).frame(maxWidth: .infinity).background(.white).clipShape(RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain)
            }
        }
    }

    private var animalsLevel: some View {
        let items = ["🐶","🍎","🐱","🍌","🐰","🚗","🐼","🍓","🦊","⭐️"]
        return LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 10) {
            ForEach(items.indices, id: \.self) { i in tile(items[i], index: i, correct: ["🐶","🐱","🐰","🐼","🦊"].contains(items[i]), size: 40) }
        }.onChange(of: found) { _, v in if v.count == 5 { finish() } }
    }

    private var starsLevel: some View {
        let items = ["⭐️","🍎","🌈","⭐️","🐶","🚗","⭐️","🍓","🌙","⭐️","🎈","🍋"]
        return LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 10) {
            ForEach(items.indices, id: \.self) { i in tile(items[i], index: i, correct: items[i] == "⭐️", size: 40) }
        }.onChange(of: found) { _, v in if v.count == 4 { finish() } }
    }

    private func prepare() {
        if level == .memory && memoryOptions.isEmpty { memoryOptions = (memoryTargets + memoryDistractors).shuffled() }
        if level == .order && orderItems.isEmpty { orderItems = Array(1...5).shuffled() }
    }

    private func finish() {
        guard !done else { return }
        GameSound.success()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { done = true }
    }
}

struct SuccessView: View {
    let onComplete: () -> Void
    var body: some View {
        Color.black.opacity(0.25).ignoresSafeArea().overlay {
            VStack(spacing: 14) {
                Text("🎉").font(.system(size: 70))
                Text("Молодец!").font(.largeTitle.bold())
                Text("Уровень пройден").font(.title3)
                Text("⭐️ ⭐️ ⭐️").font(.system(size: 30))
                Button("Следующий уровень") { GameSound.tap(); onComplete() }
                    .font(.headline).foregroundStyle(.white).frame(maxWidth: 280).padding().background(.orange).clipShape(RoundedRectangle(cornerRadius: 18))
            }.padding(28).frame(maxWidth: 350).background(.white).clipShape(RoundedRectangle(cornerRadius: 30)).shadow(radius: 20)
        }
    }
}
