import Foundation
import AVFoundation
import Speech

/// Background audio/speech worker completely decoupled from @MainActor
/// to guarantee zero runtime actor isolation assertion crashes in Swift 6.
private final class SpeechRecognitionWorker: @unchecked Sendable {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    func requestAuthorization() async -> Bool {
        // 1. Microphone permission check
        let micAllowed: Bool = await withCheckedContinuation { continuation in
            if #available(macOS 14.0, *) {
                AVAudioApplication.requestRecordPermission { @Sendable granted in
                    continuation.resume(returning: granted)
                }
            } else {
                continuation.resume(returning: true)
            }
        }
        guard micAllowed else { return false }
        
        // 2. Speech recognition authorization check
        let speechAllowed: Bool = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status == .authorized)
            }
        }
        return speechAllowed
    }
    
    func startListening(
        onText: @escaping @Sendable (String) -> Void,
        onErrorOrCompletion: @escaping @Sendable (Error?) -> Void
    ) throws {
        stopListening()
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw NSError(
                domain: "AudioVoiceService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is not available on this system."]
            )
        }
        
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request
        
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            throw NSError(
                domain: "AudioVoiceService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "No valid audio input device detected."]
            )
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        
        engine.prepare()
        try engine.start()
        
        self.recognitionTask = recognizer.recognitionTask(with: request) { @Sendable result, error in
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                onText(transcription)
            }
            if error != nil || (result?.isFinal ?? false) {
                onErrorOrCompletion(error)
            }
        }
    }
    
    func stopListening() {
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

@MainActor
@Observable
public final class AudioVoiceService: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = AudioVoiceService()
    
    public var isListening: Bool = false
    public var isSpeaking: Bool = false
    public var transcribedText: String = ""
    public var speechAuthorized: Bool = false
    
    private let worker = SpeechRecognitionWorker()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    public override init() {
        super.init()
        speechSynthesizer.delegate = self
        // Note: Do NOT request authorization during init() to avoid launch-time TCC traps.
    }
    
    @discardableResult
    public func requestAuthorization() async -> Bool {
        let authorized = await worker.requestAuthorization()
        self.speechAuthorized = authorized
        return authorized
    }
    
    public func startListening(onText: @escaping @MainActor @Sendable (String) -> Void) async throws {
        guard !isListening else { return }
        
        if !speechAuthorized {
            let authorized = await requestAuthorization()
            guard authorized else {
                throw NSError(
                    domain: "AudioVoiceService",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Microphone or Speech Recognition permission was not granted."]
                )
            }
        }
        
        self.isListening = true
        self.transcribedText = ""
        
        do {
            try worker.startListening(
                onText: { [weak self] text in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.transcribedText = text
                        onText(text)
                    }
                },
                onErrorOrCompletion: { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.stopListening()
                    }
                }
            )
        } catch {
            self.isListening = false
            throw error
        }
    }
    
    public func stopListening() {
        guard isListening else { return }
        isListening = false
        worker.stopListening()
    }
    
    public func speak(text: String) {
        let cleaned = text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "Tool: ", with: "Tool ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleaned.isEmpty else { return }
        
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.05
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        isSpeaking = true
        speechSynthesizer.speak(utterance)
    }
    
    public func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
        }
    }
}
