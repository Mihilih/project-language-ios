import Foundation
import AVFoundation
import CryptoKit
import FirebaseFunctions

/** What the speaker buttons show: which phrase is loading or playing, if any. */
struct SpeechState: Equatable {
    var key: String? = nil
    var loading: Bool = false
}

/**
 * Reads phrases aloud with Azure voices through the `speak` Cloud Function
 * (model/SpeechRepository.kt).
 *
 * Each clip is saved under Caches/tts, so replaying a phrase (flashcards!) is instant and
 * offline. Which languages have a voice comes from the `ttsLanguages` function and is kept on
 * the device, so the speaker buttons and the picker's audio badge show without waiting.
 */
@MainActor
final class SpeechRepository: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = SpeechRepository()

    private static let keySupported = "speech.supported_languages"
    /** Shown before the first list arrives; all of these have Azure voices. */
    private static let defaultSupported: Set<String> = ["en", "si", "ta", "hi", "mr"]

    /** App language codes that can be read aloud. Starts with the last known list. */
    @Published private(set) var supported: Set<String>
    @Published private(set) var state = SpeechState()

    private var player: AVAudioPlayer?
    /** Loaded or in flight; reset on failure so the next screen or picker tries again. */
    private var refreshed = false

    override init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.keySupported)
        supported = saved.map(Set.init) ?? Self.defaultSupported
        super.init()
    }

    /** Fetch the voice list once per app run (cheap; also wakes the function). */
    func refreshSupported() {
        if refreshed { return }
        refreshed = true
        Backend.functions.httpsCallable("ttsLanguages")
            .call(["codes": Languages.all.map(\.code)]) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.refreshed = false
                        print("Speech: couldn't load audio languages: \(error)")
                        return
                    }
                    guard let codes = (result?.dict["languages"] as? [Any])?.compactMap({ $0 as? String }) else { return }
                    self.supported = Set(codes)
                    UserDefaults.standard.set(codes, forKey: Self.keySupported)
                }
            }
    }

    func isSupported(_ language: String) -> Bool { supported.contains(language) }

    func keyFor(_ text: String, _ language: String) -> String { sha256("\(language)|\(text.trimmed)") }

    /**
     * Play `text` in `language`. Tapping the phrase that's playing stops it. `onError` gets a
     * user-facing message.
     */
    func speak(_ text: String, language: String, onError: @escaping (String) -> Void = { _ in }) {
        let trimmed = text.trimmed
        if trimmed.isEmpty { return }
        let key = keyFor(trimmed, language)
        if state.key == key {
            stop()
            return
        }
        stop()
        state = SpeechState(key: key, loading: true)
        Task {
            let file = cacheDir().appendingPathComponent("\(key).mp3")
            if !FileManager.default.fileExists(atPath: file.path) {
                switch await fetch(trimmed, language) {
                case .failure(let error):
                    if state.key == key { state = SpeechState() }
                    onError(error.localizedDescription)
                    return
                case .success(let audio):
                    try? audio.write(to: file)
                }
            }
            if state.key != key { return } // tapped something else meanwhile
            play(file, key: key)
        }
    }

    func stop() {
        player?.stop()
        player?.delegate = nil
        player = nil
        state = SpeechState()
    }

    private func play(_ file: URL, key: String) {
        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try? session.setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: file)
            newPlayer.delegate = self
            player = newPlayer
            state = SpeechState(key: key, loading: false)
            if !newPlayer.play() {
                throw TranslationError(message: "Couldn't play audio.")
            }
        } catch {
            print("Speech: couldn't play audio: \(error)")
            try? FileManager.default.removeItem(at: file) // a bad clip shouldn't stick around
            stop()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if self.player === player { self.stop() }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let url = player.url
        Task { @MainActor in
            if let url { try? FileManager.default.removeItem(at: url) }
            if self.player === player { self.stop() }
        }
    }

    private func fetch(_ text: String, _ language: String) async -> Result<Data, Error> {
        do {
            let result = try await Backend.functions.httpsCallable("speak").call(["text": text, "language": language])
            guard let base64 = result.dict.string("audio"),
                  let bytes = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
                return .failure(TranslationError(message: "Couldn't play audio."))
            }
            return .success(bytes)
        } catch {
            return .failure(TranslationError(message: friendlyMessage(error)))
        }
    }

    private func friendlyMessage(_ error: Error) -> String {
        switch error.functionsCode {
        case .resourceExhausted: return "Daily audio limit reached. Try again tomorrow."
        case .invalidArgument:
            return error.localizedDescription.isBlank ? "This phrase can't be read aloud." : error.localizedDescription
        case .unavailable, .deadlineExceeded: return "Couldn't reach the audio service. Check your connection."
        default: return "Couldn't play audio. Please try again."
        }
    }

    private func cacheDir() -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("tts")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
