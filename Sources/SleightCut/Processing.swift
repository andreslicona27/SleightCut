import AppKit
import AVFoundation
import CoreImage
import Speech
import UniformTypeIdentifiers

struct Caption: Identifiable { let id = UUID(); var start: Double; var end: Double; var text: String }
struct FilmError: LocalizedError { var message: String; var errorDescription: String? { message } }
@MainActor final class EditorModel: ObservableObject {
    @Published var input: URL?
    @Published var output: URL?
    @Published var player: AVPlayer?
    @Published var captions: [Caption] = []
    @Published var enhance = true
    @Published var cleanAudio = true
    @Published var captionsEnabled = true
    @Published var language = "en-US"
    @Published var busy = false
    @Published var status = "Ready when you are."
    private var recognition: SFSpeechRecognitionTask?
    func chooseVideo() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.movie]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await loadVideo(url) }
    }
    func loadVideo(_ url: URL) async {
        guard !busy else { return }
        busy = true; status = "Checking video…"
        defer { busy = false }
        do {
            let asset = AVURLAsset(url: url)
            let playable = try await asset.load(.isPlayable)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            let duration = try await asset.load(.duration)
            guard playable, !tracks.isEmpty, duration.seconds.isFinite, duration.seconds > 0 else {
                throw FilmError(message: "This file has no playable video. Try exporting it as H.264 or HEVC in an MP4 or MOV container.")
            }
            player?.pause()
            input = url
            player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
            captions = []; output = nil
            status = "Video loaded. Generate captions or export."
        } catch {
            status = "Could not open video: \(error.localizedDescription)"
        }
    }
    func transcribe() {
        guard let input, !busy else { return }
        busy = true; status = "Preparing on-device transcription…"
        Task {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { busy = false; try? FileManager.default.removeItem(at: directory) }
            do {
                let permission = await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) } }
                guard permission == .authorized else { throw FilmError(message: "Allow Speech Recognition in System Settings → Privacy & Security to generate captions.") }
                guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else { throw FilmError(message: "On-device recognition is unavailable for this language. Install its speech model in macOS settings or choose another language.") }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let audio = directory.appendingPathComponent("speech.m4a")
                let asset = AVURLAsset(url: input)
                guard !(try await asset.loadTracks(withMediaType: .audio)).isEmpty else { throw FilmError(message: "This video has no audio track.") }
                try await exportAsset(asset, to: audio, preset: AVAssetExportPresetAppleM4A, type: .m4a)
                let request = SFSpeechURLRecognitionRequest(url: audio); request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = false
                let segments: [SFTranscriptionSegment] = try await withCheckedThrowingContinuation { continuation in
                    var finished = false
                    recognition = recognizer.recognitionTask(with: request) { result, error in
                        guard !finished else { return }
                        if let result, result.isFinal { finished = true; continuation.resume(returning: result.bestTranscription.segments) }
                        else if let error { finished = true; continuation.resume(throwing: error) }
                    }
                }
                recognition = nil
                var generated: [Caption] = []; var words: [String] = []; var start = 0.0; var end = 0.0
                for segment in segments {
                    if !words.isEmpty && (words.count >= 8 || segment.timestamp - end > 0.7) { generated.append(Caption(start: start, end: end + 0.15, text: words.joined(separator: " "))); words = [] }
                    if words.isEmpty { start = segment.timestamp }
                    words.append(segment.substring); end = segment.timestamp + segment.duration
                }
                if !words.isEmpty { generated.append(Caption(start: start, end: end + 0.2, text: words.joined(separator: " "))) }
                captions = generated; status = generated.isEmpty ? "No speech detected. You can export without captions." : "Captions ready. Review dialogue and timing before export."
            } catch { status = error.localizedDescription }
        }
    }
    func exportVideo() {
        guard let input, !busy else { return }
        if captionsEnabled && captions.isEmpty { status = "Generate captions first, or turn off Burn in captions."; return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.mpeg4Movie]; panel.nameFieldStringValue = input.deletingPathExtension().lastPathComponent + "-sleightcut.mp4"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        guard destination.standardizedFileURL != input.standardizedFileURL else { status = "Choose a different filename to preserve your original."; return }
        busy = true; status = "Rendering your film…"
        let selectedCaptions = captionsEnabled ? captions : []; let improve = enhance; let cleanup = cleanAudio
        Task {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { busy = false; try? FileManager.default.removeItem(at: directory) }
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let asset = AVURLAsset(url: input)
                let duration = try await asset.load(.duration)
                guard !(try await asset.loadTracks(withMediaType: .video)).isEmpty else { throw FilmError(message: "No supported video track was found.") }
                for caption in selectedCaptions {
                    guard caption.start.isFinite, caption.end.isFinite, caption.start >= 0, caption.end > caption.start, caption.end <= duration.seconds + 0.5 else { throw FilmError(message: "Caption timing must be within the video, with end after start.") }
                }
                let composition = AVMutableComposition()
                try await composition.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: asset, at: .zero)
                if cleanup, let originalAudio = try await asset.loadTracks(withMediaType: .audio).first {
                    let audioOnly = AVMutableComposition()
                    let track = audioOnly.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
                    try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: originalAudio, at: .zero)
                    let extracted = directory.appendingPathComponent("audio.m4a")
                    try await exportAsset(audioOnly, to: extracted, preset: AVAssetExportPresetAppleM4A, type: .m4a)
                    let cleaned = directory.appendingPathComponent("clean.caf")
                    try await Task.detached { try speechClarity(input: extracted, output: cleaned) }.value
                    let cleanAsset = AVURLAsset(url: cleaned)
                    if let cleanTrack = try await cleanAsset.loadTracks(withMediaType: .audio).first {
                        for old in composition.tracks(withMediaType: .audio) { composition.removeTrack(old) }
                        let newTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
                        let audioDuration = try await cleanAsset.load(.duration)
                        try newTrack.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(duration, audioDuration)), of: cleanTrack, at: .zero)
                    }
                }
                let videoTrack = try await composition.loadTracks(withMediaType: .video).first!
                let naturalSize = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                let bounds = CGRect(origin: .zero, size: naturalSize).applying(transform)
                let renderSize = CGSize(width: abs(bounds.width), height: abs(bounds.height))
                let overlays = selectedCaptions.map { ($0, captionImage(text: $0.text, size: renderSize)) }
                let video = AVVideoComposition(asset: composition) { request in
                    let extent = request.sourceImage.extent
                    var frame = request.sourceImage
                    if improve {
                        frame = frame.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.06, kCIInputSaturationKey: 1.04])
                        frame = frame.clampedToExtent().applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: 0.3]).cropped(to: extent)
                    }
                    if let item = overlays.first(where: { request.compositionTime.seconds >= $0.0.start && request.compositionTime.seconds < $0.0.end }), let overlay = item.1 {
                        frame = overlay.composited(over: frame)
                    }
                    request.finish(with: frame, context: nil)
                }
                let temporary = directory.appendingPathComponent("finished.mp4")
                try await exportAsset(composition, to: temporary, preset: AVAssetExportPresetHighestQuality, type: .mp4, video: video)
                if FileManager.default.fileExists(atPath: destination.path) { _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary) }
                else { try FileManager.default.moveItem(at: temporary, to: destination) }
                output = destination; player?.pause(); player = AVPlayer(url: destination); status = "Export complete. Preview your finished film above."
            } catch { status = "Export failed: \(error.localizedDescription)" }
        }
    }
}
func exportAsset(_ asset: AVAsset, to url: URL, preset: String, type: AVFileType, video: AVVideoComposition? = nil) async throws {
    guard let session = AVAssetExportSession(asset: asset, presetName: preset) else { throw FilmError(message: "This media cannot be exported with the selected settings.") }
    session.outputURL = url; session.outputFileType = type; session.videoComposition = video; session.shouldOptimizeForNetworkUse = true
    await session.export()
    guard session.status == .completed else { throw session.error ?? FilmError(message: "Media export did not complete.") }
}
func speechClarity(input: URL, output: URL) throws {
    let file = try AVAudioFile(forReading: input)
    let engine = AVAudioEngine(); let player = AVAudioPlayerNode(); let eq = AVAudioUnitEQ(numberOfBands: 3)
    engine.attach(player); engine.attach(eq)
    let settings: [(AVAudioUnitEQFilterType, Float, Float)] = [(.highPass, 100, 0), (.lowPass, 8000, 0), (.parametric, 2500, 2)]
    for (band, setting) in zip(eq.bands, settings) { band.filterType = setting.0; band.frequency = setting.1; band.gain = setting.2; band.bandwidth = 1; band.bypass = false }
    engine.connect(player, to: eq, format: file.processingFormat); engine.connect(eq, to: engine.mainMixerNode, format: file.processingFormat)
    try engine.enableManualRenderingMode(.offline, format: file.processingFormat, maximumFrameCount: 4096)
    let result = try AVAudioFile(forWriting: output, settings: engine.manualRenderingFormat.settings)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096) else { throw FilmError(message: "Cannot allocate audio buffer.") }
    player.scheduleFile(file, at: nil); try engine.start(); player.play()
    defer { player.stop(); engine.stop() }
    var retries = 0
    while engine.manualRenderingSampleTime < file.length {
        let count = AVAudioFrameCount(min(4096, file.length - engine.manualRenderingSampleTime))
        let status = try engine.renderOffline(count, to: buffer)
        switch status {
        case .success: try result.write(from: buffer); retries = 0
        case .cannotDoInCurrentContext, .insufficientDataFromInputNode: retries += 1; if retries > 100 { throw FilmError(message: "Audio processing stalled.") }
        case .error: throw FilmError(message: "Audio processing failed.")
        @unknown default: throw FilmError(message: "Unsupported audio render status.")
        }
    }
}
func captionImage(text: String, size: CGSize) -> CIImage? {
    let width = size.width * 0.86; let fontSize = max(18, size.width * 0.032)
    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: fontSize, weight: .semibold), .foregroundColor: NSColor(red: 252/255, green: 243/255, blue: 242/255, alpha: 1), .paragraphStyle: paragraph]
    let string = NSAttributedString(string: text, attributes: attributes)
    let textHeight = string.boundingRect(with: CGSize(width: width - 40, height: size.height), options: [.usesLineFragmentOrigin, .usesFontLeading]).height
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(ceil(width)), pixelsHigh: Int(ceil(textHeight + 32)), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    let rect = CGRect(x: 0, y: 0, width: width, height: textHeight + 32)
    NSColor(red: 14/255, green: 5/255, blue: 5/255, alpha: 0.9).setFill(); NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
    NSColor(red: 219/255, green: 43/255, blue: 51/255, alpha: 1).setFill(); NSBezierPath(rect: CGRect(x: rect.minX + 16, y: rect.minY, width: rect.width - 32, height: 4)).fill()
    string.draw(with: rect.insetBy(dx: 20, dy: 16), options: [.usesLineFragmentOrigin, .usesFontLeading])
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.cgImage.map { CIImage(cgImage: $0).transformed(by: CGAffineTransform(translationX: (size.width - width)/2, y: size.height * 0.08)) }
}
