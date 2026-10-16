import SwiftUI
import UniformTypeIdentifiers

// MARK: - Track Model
struct Track: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let duration: String
}

// MARK: - View Model
class PlayerViewModel: ObservableObject {
    @Published var tracks: [Track] = [
        Track(title: "Untrust Us", artist: "Crystal Castles", duration: "3:06"),
        Track(title: "Kerosene", artist: "Crystal Castles", duration: "3:00"),
        Track(title: "Мама, я не зигую", artist: "Монеточка", duration: "2:50"),
        Track(title: "Дом Периньон", artist: "Пошлая Молли", duration: "2:54"),
        Track(title: "Call The Doctor", artist: "Pissgoblin", duration: "2:49"),
        Track(title: "Пожары", artist: "XOLIDAYBOY", duration: "3:18"),
    ]
    
    @Published var currentTrack: Track? = nil
    @Published var isPlaying: Bool = false
    
    func play(_ track: Track) {
        currentTrack = track
        isPlaying = true
    }
    
    func togglePlay() {
        isPlaying.toggle()
    }
    
    func next() {
        guard let current = currentTrack,
              let index = tracks.firstIndex(where: { $0.id == current.id }) else { return }
        currentTrack = tracks[(index + 1) % tracks.count]
    }
    
    func previous() {
        guard let current = currentTrack,
              let index = tracks.firstIndex(where: { $0.id == current.id }) else { return }
        currentTrack = tracks[(index - 1 + tracks.count) % tracks.count]
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
                TrackList(viewModel: viewModel)
                Spacer(minLength: 0)
            }
        }
        .overlay(
            VStack {
                Spacer()
                if let track = viewModel.currentTrack {
                    MiniPlayer(viewModel: viewModel, track: track)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
            }
        )
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.audio],
            allowsMultipleSelection: true
        ) { result in
            print(result)
        }
    }
}

// MARK: - Background (красные размытые круги)
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
                            
                            Text(track.duration)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(15)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }
}

// MARK: - Mini Player (Liquid Glass)
struct MiniPlayer: View {
    @ObservedObject var viewModel: PlayerViewModel
    let track: Track
    
    var body: some View {
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
            
            Spacer()
            
            Button(action: { viewModel.previous() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            
            Button(action: { viewModel.togglePlay() }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
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

// MARK: - Liquid Glass (UIBlurEffect)
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}