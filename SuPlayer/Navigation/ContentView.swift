import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

// MARK: - Track Model
struct Track: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let artist: String
    let url: URL
    let durationText: String

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Audio Player
final class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    var onFinish: (() -> Void)?

    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Audio session error: \(error)")
        }
    }

    func load(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            currentTime = 0
            progress = 0
            print("✅ Loaded: \(url.lastPathComponent), duration: \(duration)s")
        } catch {
            print("❌ Load error: \(error)")
            player = nil
        }
    }

    func play() {
        guard player != nil else { return }
        player?.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func toggle() {
        guard player != nil else { return }
        if isPlaying { pause() } else { play() }
    }

    func seek(to value: Double) {
        guard let player = player else { return }
        player.currentTime = value * player.duration
        currentTime = player.currentTime
        progress = value
    }

    func stop() {
        player?.stop()
        isPlaying = false
        stopTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.currentTime = player.currentTime
            if player.duration > 0 {
                self.progress = player.currentTime / player.duration
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopTimer()
        onFinish?()
    }
}

// MARK: - View Model
final class PlayerViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var currentTrack: Track? = nil
    @Published var showFullPlayer = false

    let audio = AudioPlayer()

    init() {
        audio.onFinish = { [weak self] in
            self?.next()
        }
        loadSavedTracks()
    }

    func play(_ track: Track) {
        currentTrack = track
        audio.load(url: track.url)
        audio.play()
        showFullPlayer = true
    }

    func togglePlay() {
        audio.toggle()
    }

    func next() {
        guard let current = currentTrack,
              let index = tracks.firstIndex(where: { $0.id == current.id }),
              !tracks.isEmpty else { return }
        play(tracks[(index + 1) % tracks.count])
    }

    func previous() {
        guard let current = currentTrack,
              let index = tracks.firstIndex(where: { $0.id == current.id }),
              !tracks.isEmpty else { return }
        play(tracks[(index - 1 + tracks.count) % tracks.count])
    }

    // MARK: Import (asCopy уже скопировал файл — просто переносим)
    func importFiles(_ urls: [URL]) {
        print("📥 Импорт: \(urls.count) файл(ов)")

        for url in urls {
            print("   → \(url.lastPathComponent)")

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dest = docs.appendingPathComponent(url.lastPathComponent)

            // asCopy: true → файл уже во временной папке, копируем к себе если нет
            if !FileManager.default.fileExists(atPath: dest.path) {
                do {
                    try FileManager.default.copyItem(at: url, to: dest)
                    print("   ✅ Скопировано в: \(dest.path)")
                } catch {
                    print("   ❌ Ошибка копирования: \(error)")
                    continue
                }
            } else {
                print("   ℹ️ Файл уже есть: \(dest.lastPathComponent)")
            }

            // Не добавляем дубликаты
            if tracks.contains(where: { $0.url == dest }) {
                print("   ℹ️ Уже в списке")
                continue
            }

            let name = url.deletingPathExtension().lastPathComponent
            let newTrack = Track(
                title: name,
                artist: "Импорт",
                url: dest,
                durationText: durationString(for: dest)
            )
            tracks.append(newTrack)
        }

        saveTracks()
        print("📚 Всего треков: \(tracks.count)")
    }

    // MARK: Persistence
    private func saveTracks() {
        let paths = tracks.map { $0.url.path }
        UserDefaults.standard.set(paths, forKey: "savedTrackPaths")
    }

    private func loadSavedTracks() {
        guard let paths = UserDefaults.standard.stringArray(forKey: "savedTrackPaths") else { return }
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let name = url.deletingPathExtension().lastPathComponent
            let track = Track(
                title: name,
                artist: "Импорт",
                url: url,
                durationText: durationString(for: url)
            )
            tracks.append(track)
        }
        print("📚 Загружено треков: \(tracks.count)")
    }

    private func durationString(for url: URL) -> String {
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return "—" }
        let total = Int(p.duration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    func delete(_ track: Track) {
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            try? FileManager.default.removeItem(at: track.url)
            tracks.remove(at: index)

            if currentTrack?.id == track.id {
                audio.stop()
                currentTrack = nil
            }
            saveTracks()
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    var body: some View {
        MainView()
    }
}

// MARK: - Main View
struct MainView: View {
    @StateObject private var viewModel = PlayerViewModel()
    @State private var showFilePicker = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            BackgroundView()

            VStack(spacing: 0) {
                TopBar(showFilePicker: $showFilePicker, openURL: openURL)

                if viewModel.tracks.isEmpty {
                    EmptyStateView(showFilePicker: $showFilePicker)
                } else {
                    TrackList(viewModel: viewModel)
                }

                Spacer(minLength: 0)
            }
        }
        .overlay(
            VStack {
                Spacer()
                if let track = viewModel.currentTrack {
                    MiniPlayer(viewModel: viewModel,
                               audio: viewModel.audio,
                               track: track)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
            }
        )
        .sheet(isPresented: $viewModel.showFullPlayer) {
            FullPlayerView(viewModel: viewModel, audio: viewModel.audio)
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker(contentTypes: [.audio]) { urls in
                print("✅ Выбрано: \(urls)")
                viewModel.importFiles(urls)
            }
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    @Binding var showFilePicker: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 70, weight: .light))
                .foregroundColor(.white.opacity(0.3))

            Text("Пока нет треков")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)

            Text("Нажми «+» сверху или кнопку ниже,\nчтобы добавить музыку")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Button(action: { showFilePicker = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Добавить треки")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.red, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .padding(.top, 10)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Background
struct BackgroundView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(Color.red.opacity(0.85))
                .frame(width: 350, height: 350)
                .blur(radius: 100)
                .offset(x: -120, y: -250)

            Circle()
                .fill(Color.red.opacity(0.7))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: 140, y: -100)

            Circle()
                .fill(Color.red.opacity(0.6))
                .frame(width: 240, height: 240)
                .blur(radius: 80)
                .offset(x: -80, y: 350)

            Circle()
                .fill(Color.orange.opacity(0.5))
                .frame(width: 200, height: 200)
                .blur(radius: 70)
                .offset(x: 160, y: 300)
        }
    }
}

// MARK: - Top Bar
struct TopBar: View {
    @Binding var showFilePicker: Bool
    let openURL: OpenURLAction

    var body: some View {
        HStack(spacing: 20) {
            Text("SuPlayer")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button(action: {
                if let url = URL(string: "https://mp3party.net") {
                    openURL(url)
                }
            }) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }

            Button(action: { showFilePicker = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

// MARK: - Track List
struct TrackList: View {
    @ObservedObject var viewModel: PlayerViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.tracks) { track in
                    Button(action: { viewModel.play(track) }) {
                        HStack(spacing: 15) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.35))
                                .frame(width: 55, height: 55)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(track.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(track.durationText)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(15)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.delete(track)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
    }
}

// MARK: - Mini Player
struct MiniPlayer: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var audio: AudioPlayer
    let track: Track

    var body: some View {
        HStack(spacing: 15) {
            HStack(spacing: 15) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.4))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { viewModel.showFullPlayer = true }

            Spacer()

            Button(action: { viewModel.previous() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }

            Button(action: { viewModel.togglePlay() }) {
                Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }

            Button(action: { viewModel.next() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
        }
        .padding(12)
        .background(
            VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                .cornerRadius(20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Full Player
struct FullPlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var audio: AudioPlayer
    @Environment(\.dismiss) private var dismiss

    private var track: Track? { viewModel.currentTrack }

    var body: some View {
        ZStack {
            BackgroundView()

            VStack(spacing: 25) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            colors: [.red, .orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 280, height: 280)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 80, weight: .light))
                            .foregroundColor(.white.opacity(0.9))
                    )
                    .shadow(color: .red.opacity(0.6), radius: 40)

                VStack(spacing: 8) {
                    Text(track?.title ?? "—")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                    Text(track?.artist ?? "")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }
                .padding(.horizontal, 30)

                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { audio.progress },
                            set: { audio.seek(to: $0) }
                        ),
                        in: 0...1
                    )
                    .accentColor(.white)

                    HStack {
                        Text(formatTime(audio.currentTime))
                        Spacer()
                        Text(formatTime(audio.duration))
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.55))
                }
                .padding(.horizontal, 30)

                HStack(spacing: 45) {
                    Button(action: { viewModel.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.white)
                    }

                    Button(action: { viewModel.togglePlay() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 90, height: 90)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: .white.opacity(0.2), radius: 20)
                            Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 38))
                                .foregroundColor(.white)
                                .offset(x: audio.isPlaying ? 0 : 3)
                        }
                    }

                    Button(action: { viewModel.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 20)

                Spacer()
            }
        }
    }

    private func formatTime(_ t: Double) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Liquid Glass
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPicked: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: contentTypes,
            asCopy: true
        )
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPicked(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("📂 Пикер закрыт без выбора")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}