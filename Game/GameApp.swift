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

struct Level: Identifiable, Hashable {
    let rawValue: Int
    var id: Int { rawValue }
    static let allCases: [Level] = (1...100).map { Level(rawValue: $0) }

    var title: String {
        switch rawValue {
        case 1: return "Найди красные фрукты"
        case 2: return "Тренируем память"
        case 3: return "Посчитай яблоки"
        case 4: return "Найди лишнее"
        case 5: return "Продолжи ряд"
        case 6: return "Найди самый большой"
        case 7: return "Найди синие предметы"
        case 8: return "Нажми по порядку"
        case 9: return "Найди животных"
        case 10: return "Собери звёздочки"
        default: return "Умное задание №\\(rawValue)"
        }
    }

    var icon: String {
        let icons = ["🎨","🧠","🔢","👀","🧩","📏","🔵","🔢","🐾","⭐️"]
        return rawValue <= 10 ? icons[rawValue - 1] : ["🍎","🐻","🧩","🔢","🌈","⭐️","🚀","🎯"].randomElement()!
    }
}

struct HomeView: View {
    @State private var selected: Level?
    @AppStorage("unlockedLevel") private var unlocked = 1
    @State private var showSettings = false
    @AppStorage("totalScore") private var totalScore = 0

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.cyan.opacity(0.2), .blue.opacity(0.08)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        Text("🐻").font(.system(size: 80))
                        Text("Мир Мишки").font(.system(size: 34, weight: .heavy, design: .rounded))
                        Text("100 уровней + умный режим ∞").font(.headline).foregroundStyle(.secondary)
                        HStack(spacing: 8) { Text("⭐️").font(.title2); Text("Всего баллов: \(totalScore)").font(.headline.bold()) }
                            .padding(.horizontal, 16).padding(.vertical, 9).background(.white.opacity(0.9)).clipShape(Capsule())

                        VStack(spacing: 10) {
                            NavigationLink { SmartLevelsView() } label: {
                                Label("Умные уровни ∞", systemImage: "brain.head.profile")
                                    .font(.headline).padding(.vertical, 10).frame(maxWidth: .infinity)
                            }.buttonStyle(.borderedProminent)
                            Button { GameSound.tap(); showSettings = true } label: {
                                Label("Настройки звука", systemImage: "speaker.wave.2.fill")
                                    .font(.headline).padding(.vertical, 10).frame(maxWidth: .infinity)
                            }.buttonStyle(.borderedProminent)
                        }

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
                    unlocked = max(unlocked, min(100, level.rawValue + 1))
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
    @State private var bearBounce = false
    @State private var showSparkles = false
    @State private var generatedRound: SmartRound?
    @State private var generatedSelected = Set<Int>()
    @State private var generatedWrong = Set<Int>()
    @AppStorage("totalScore") private var totalScore = 0

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
                BearView()
                Text(prompt).font(.title2.bold()).multilineTextAlignment(.center)
                content
                Spacer()
            }.padding()
            if done { SuccessView(onComplete: onComplete) }
        }
        .onAppear { prepare() }
    }

    private var prompt: String {
        if level.rawValue > 10 { return generatedRound?.title ?? "Готовим задание..." }
        switch level.rawValue {
        case 1: return "Найди все красные фрукты!"
        case 2: return "Запомни картинки и найди их среди других!"
        case 3: return "Сколько яблок?"
        case 4: return "Найди предмет, который отличается!"
        case 5: return "Что должно быть дальше?"
        case 6: return "Нажми на самый большой предмет!"
        case 7: return "Найди все синие предметы!"
        case 8: return "Нажимай числа от 1 до 5"
        case 9: return "Найди всех животных!"
        default: return "Собери все звёздочки!"
        }
    }

    @ViewBuilder private var content: some View {
        if level.rawValue > 10 {
            generatedLevel
        } else {
            switch level.rawValue {
            case 1: colorsLevel
            case 2: memoryLevel
            case 3: countingLevel
            case 4: oddLevel
            case 5: patternLevel
            case 6: sizeLevel
            case 7: blueLevel
            case 8: orderLevel
            case 9: animalsLevel
            default: starsLevel
            }
        }
    }

    private func addPoints(_ points: Int) { score += points; totalScore += points }

    private func tile(_ text: String, index: Int, correct: Bool, size: CGFloat = 76) -> some View {
        Button {
            guard !found.contains(index) && !wrong.contains(index) else { return }
            GameSound.tap()
            if correct {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) { found.insert(index); addPoints(1) }
                GameSound.correct()
            } else {
                _ = withAnimation(.easeInOut(duration: 0.12)) { wrong.insert(index) }
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
        .onChange(of: found) { v in if v.count == 3 { finish() } }
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
            memoryFound.insert(item); addPoints(1); GameSound.correct()
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
        Button { GameSound.tap(); if n == 5 { addPoints(3); GameSound.correct(); finish() } else { GameSound.wrong() } } label: {
            Text("\(n)")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 88, height: 88)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.black, lineWidth: 3))
                )
                .shadow(radius: 3)
        }.buttonStyle(.plain)
    }

    private var oddLevel: some View {
        LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 10) {
            let items = ["⭐️","⭐️","⭐️","🌙","⭐️","⭐️","⭐️","⭐️"]
            ForEach(items.indices, id: \.self) { i in tile(items[i], index: i, correct: i == 3, size: 40) }
        }
        .onChange(of: found) { v in if v.contains(3) { finish() } }
    }

    private var patternLevel: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) { Text("🔴").font(.system(size: 42)); Text("🔵").font(.system(size: 42)); Text("🔴").font(.system(size: 42)); Text("🔵").font(.system(size: 42)); Text("🔴").font(.system(size: 42)); Text("❓").font(.system(size: 42)).scaleEffect(1.08) }
            Text("Красный круг — следующий!").font(.headline).foregroundStyle(.red)
            HStack { answerPattern("🔴", correct: true); answerPattern("🔵", correct: false); answerPattern("🟢", correct: false) }
        }
    }

    private func answerPattern(_ text: String, correct: Bool) -> some View {
        Button { GameSound.tap(); if correct { addPoints(5); GameSound.correct(); finish() } else { GameSound.wrong() } } label: {
            Text(text).font(.system(size: 40)).frame(width: 80, height: 80).background(.white).clipShape(Circle())
        }.buttonStyle(.plain)
    }

    private var sizeLevel: some View {
        HStack(alignment: .center, spacing: 8) {
            let sizes: [CGFloat] = [42, 58, 76, 50, 64, 46]
            ForEach(sizes.indices, id: \.self) { i in tile(["🍎","🍊","🍋","🍓","🍐","🍒"][i], index: i, correct: i == 2, size: sizes[i] * 0.72) }
        }.onChange(of: found) { v in if v.contains(2) { finish() } }
    }

    private var blueLevel: some View {
        let items = ["🔵","🟢","🔴","🔵","🟡","🟣","🔵","🟠","🔵","🟢"]
        return LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 10) {
            ForEach(items.indices, id: \.self) { i in tile(items[i], index: i, correct: items[i] == "🔵", size: 40) }
        }.onChange(of: found) { v in if v.count == 4 { finish() } }
    }

    private var orderLevel: some View {
        LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 12) {
            ForEach(orderItems, id: \.self) { n in
                Button {
                    GameSound.tap()
                    if n == nextNumber {
                        addPoints(1); GameSound.correct()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { orderItems.removeAll { $0 == n }; nextNumber += 1 }
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
        }.onChange(of: found) { v in if v.count == 5 { finish() } }
    }

    private var starsLevel: some View {
        let items = ["⭐️","🍎","🌈","⭐️","🐶","🚗","⭐️","🍓","🌙","⭐️","🎈","🍋"]
        return LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 10) {
            ForEach(items.indices, id: \.self) { i in tile(items[i], index: i, correct: items[i] == "⭐️", size: 40) }
        }.onChange(of: found) { v in if v.count == 4 { finish() } }
    }

    private var generatedLevel: some View {
        let r = generatedRound ?? SmartGenerator.make(difficulty: max(1, min(10, level.rawValue / 10 + 1)))
        return VStack(spacing: 14) {
            Text("Уровень \(level.rawValue) из 100")
                .font(.headline)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(r.items.indices, id: \.self) { index in
                    Button {
                        guard !generatedSelected.contains(index) && !generatedWrong.contains(index) else { return }
                        GameSound.tap()
                        if r.answers.contains(index) {
                            generatedSelected.insert(index)
                            addPoints(r.points)
                            GameSound.correct()
                            if generatedSelected.isSuperset(of: r.answers) { finish() }
                        } else {
                            generatedWrong.insert(index)
                            GameSound.wrong()
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.white)
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.black.opacity(0.15), lineWidth: 2))
                                .frame(height: 76)
                            Text(r.items[index])
                                .font(.system(size: r.items[index].count <= 2 ? 40 : 23, weight: .bold))
                                .foregroundStyle(.black)
                            if generatedSelected.contains(index) {
                                Text("✓").font(.title.bold()).foregroundStyle(.green).padding(5)
                            } else if generatedWrong.contains(index) {
                                Text("✕").font(.title.bold()).foregroundStyle(.red).padding(5)
                            }
                        }
                        .scaleEffect(generatedSelected.contains(index) ? 1.05 : generatedWrong.contains(index) ? 0.94 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func prepare() {
        if level.rawValue > 10 && generatedRound == nil {
            generatedRound = SmartGenerator.make(difficulty: max(1, min(10, level.rawValue / 10 + 1)))
        }
        if level.rawValue == 2 && memoryOptions.isEmpty { memoryOptions = (memoryTargets + memoryDistractors).shuffled() }
        if level.rawValue == 8 && orderItems.isEmpty { orderItems = Array(1...5).shuffled() }
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bearBounce = true }
    }

    private func finish() {
        guard !done else { return }
        GameSound.success()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { done = true; showSparkles = true }
    }
}

struct BearView: View {
    @State private var jump = false
    @State private var sway = false
    var body: some View {
        Text("🐻").font(.system(size: 58)).offset(y: jump ? -8 : 0).rotationEffect(.degrees(sway ? 4 : -4))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { jump = true }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { sway = true }
            }
    }
}

struct SuccessView: View {
    let onComplete: () -> Void
    var body: some View {
        Color.black.opacity(0.25).ignoresSafeArea().overlay {
            VStack(spacing: 14) {
                ZStack {
                    Text("🎉").font(.system(size: 70)).scaleEffect(1.0)
                    Text("✨ ⭐️ ✨ ⭐️ ✨").font(.system(size: 26)).offset(y: -58).transition(.scale)
                }
                Text("Молодец!").font(.largeTitle.bold())
                Text("Уровень пройден").font(.title3)
                Text("⭐️ ⭐️ ⭐️").font(.system(size: 30))
                Button("Следующий уровень") { GameSound.tap(); onComplete() }
                    .font(.headline).foregroundStyle(.white).frame(maxWidth: 280).padding().background(.orange).clipShape(RoundedRectangle(cornerRadius: 18))
            }.padding(28).frame(maxWidth: 350).background(.white).clipShape(RoundedRectangle(cornerRadius: 30)).shadow(radius: 20)
        }
    }
}

    
// MARK: Smart endless mode

enum SmartKind: CaseIterable {
    case color, fruit, animal, count, pattern, odd
}

struct SmartRound {
    let title: String
    let items: [String]
    let answers: Set<Int>
    let points: Int
}

enum SmartGenerator {
    static func make(difficulty: Int) -> SmartRound {
        let d = max(1, min(10, difficulty))
        switch SmartKind.allCases.randomElement()! {
        case .color:
            let target = ["🔴", "🔵", "🟢", "🟡"].randomElement()!
            var items = [target, target, target]
            let others = ["🔴", "🔵", "🟢", "🟡", "🟣", "🟠"].filter { $0 != target }
            items += Array(others.shuffled().prefix(5 + d / 3))
            items.shuffle()
            return SmartRound(title: "Найди все \(target) предметы", items: items,
                              answers: Set(items.indices.filter { items[$0] == target }), points: 1)
        case .fruit:
            let target = ["🍎", "🍓", "🍒", "🍌", "🍊", "🍋", "🥝", "🍇"].randomElement()!
            var items = [target, target]
            items += Array(["🍎", "🍓", "🍒", "🍌", "🍊", "🍋", "🥝", "🍇"].shuffled().prefix(6 + d / 2))
            items.shuffle()
            return SmartRound(title: "Найди все \(target)", items: items,
                              answers: Set(items.indices.filter { items[$0] == target }), points: 2)
        case .animal:
            let animals = ["🐶", "🐱", "🐰", "🐼", "🦊", "🐸", "🐯"]
            let other = ["🍎", "🚗", "⭐️", "🎈", "🌈", "⚽️"]
            var items = Array(animals.shuffled().prefix(min(3 + d / 2, 6)))
            items += Array(other.shuffled().prefix(5))
            items.shuffle()
            return SmartRound(title: "Найди всех животных", items: items,
                              answers: Set(items.indices.filter { animals.contains(items[$0]) }), points: 2)
        case .count:
            let n = 3 + Int.random(in: 0...min(7, d))
            let correct = String(n)
            var answers = [correct, String(max(1, n - 1)), String(n + 1), String(n + 2)]
            answers.shuffle()
            return SmartRound(title: "Сколько яблок? \(String(repeating: "🍎", count: n))",
                              items: answers, answers: Set(answers.indices.filter { answers[$0] == correct }), points: 3)
        case .pattern:
            let pair = [["🔴", "🔵"], ["⭐️", "🌙"], ["🍎", "🍌"], ["🟢", "🟡"]].randomElement()!
            let expected = pair[0]
            return SmartRound(title: "Продолжи ряд: \(pair[0]) \(pair[1]) \(pair[0]) \(pair[1]) \(pair[0]) ❓",
                              items: [expected, pair[1], "🟣"],
                              answers: Set([0]), points: 4)
        case .odd:
            let common = ["🍎", "🍎", "🍎", "🍎", "🍎", "🍎", "🍎"]
            let odd = ["🍐", "🍌", "🍊", "🍓"].randomElement()!
            var items = common + [odd]
            items.shuffle()
            return SmartRound(title: "Найди лишний фрукт", items: items,
                              answers: Set(items.indices.filter { items[$0] == odd }), points: 3)
        }
    }
}

struct SmartLevelsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("smartDifficulty") private var difficulty = 1
    @AppStorage("smartScore") private var smartScore = 0
    @AppStorage("totalScore") private var totalScore = 0
    @State private var roundNumber = 1
    @State private var streak = 0
    @State private var selected = Set<Int>()
    @State private var wrong = Set<Int>()
    @State private var finished = false
    @State private var bearJump = false
    @State private var round = SmartGenerator.make(difficulty: 1)

    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple.opacity(0.15), .cyan.opacity(0.12)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    Button("Закрыть") { dismiss() }
                    Spacer()
                    Text("🧠 Умные уровни").bold()
                    Spacer()
                    Text("⭐️ \(smartScore)").bold()
                }
                HStack {
                    Text("🐻").font(.system(size: 64))
                        .offset(y: bearJump ? -7 : 3)
                        .rotationEffect(.degrees(bearJump ? 5 : -5))
                    VStack(alignment: .leading) {
                        Text("Раунд \(roundNumber)").font(.headline)
                        Text("Сложность \(difficulty)/10").font(.subheadline)
                        if streak > 0 { Text("Серия: \(streak) 🔥").font(.subheadline.bold()) }
                    }
                    Spacer()
                }
                Text(round.title).font(.title2.bold()).multilineTextAlignment(.center)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(round.items.indices, id: \.self) { index in
                        Button { choose(index) } label: {
                            ZStack(alignment: .topTrailing) {
                                Text(round.items[index])
                                    .font(.system(size: round.items[index].count <= 2 ? 42 : 24, weight: .bold))
                                    .frame(maxWidth: .infinity, minHeight: 72)
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18)
                                        .stroke(selected.contains(index) ? .green : wrong.contains(index) ? .red : .clear, lineWidth: 5))
                                    .scaleEffect(selected.contains(index) ? 1.05 : wrong.contains(index) ? 0.94 : 1)
                                if selected.contains(index) {
                                    Text("✓").font(.title.bold()).foregroundStyle(.green).padding(5)
                                } else if wrong.contains(index) {
                                    Text("✕").font(.title.bold()).foregroundStyle(.red).padding(5)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(selected.contains(index) || wrong.contains(index))
                    }
                }
                Text("ИИ подбирает следующее задание по твоим результатам.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Spacer()
            }
            .padding()
            if finished { smartFinish }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                bearJump = true
            }
        }
    }

    private var smartFinish: some View {
        Color.black.opacity(0.25).ignoresSafeArea().overlay {
            VStack(spacing: 12) {
                Text("🎉").font(.system(size: 70))
                Text("Отлично!").font(.largeTitle.bold())
                Text("+\(round.points) ⭐️").font(.title2.bold())
                Button("Следующее задание") { nextRound() }
                    .font(.headline).foregroundStyle(.white)
                    .padding().frame(maxWidth: 280)
                    .background(.orange).clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding(28).frame(maxWidth: 350)
            .background(.white).clipShape(RoundedRectangle(cornerRadius: 30))
            .shadow(radius: 20)
        }
    }

    private func choose(_ index: Int) {
        GameSound.tap()
        if round.answers.contains(index) {
            selected.insert(index)
            smartScore += round.points
            totalScore += round.points
            GameSound.correct()
            if selected.isSuperset(of: round.answers) {
                streak += 1
                if streak >= 2 { difficulty = min(10, difficulty + 1) }
                finished = true
            }
        } else {
            wrong.insert(index)
            streak = 0
            difficulty = max(1, difficulty - 1)
            GameSound.wrong()
        }
    }

    private func nextRound() {
        selected.removeAll()
        wrong.removeAll()
        finished = false
        roundNumber += 1
        round = SmartGenerator.make(difficulty: difficulty)
    }
}
