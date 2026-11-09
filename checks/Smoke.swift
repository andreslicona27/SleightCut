import AppKit
import AVFoundation
import CoreImage

@main struct Smoke {
    static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SleightCut-check-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let audio = folder.appendingPathComponent("tone.caf")
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        do {
            let file = try AVAudioFile(forWriting: audio, settings: format.settings)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000)!
            buffer.frameLength = 48000
            for i in 0..<48000 { buffer.floatChannelData![0][i] = Float(sin(Double(i) * 2 * .pi * 1000 / 48000)) * 0.2 }
            try file.write(from: buffer)
        }
        let clean = folder.appendingPathComponent("clean.caf")
        try speechClarity(input: audio, output: clean)
        let renderedAudio = try AVAudioFile(forReading: clean)
        guard renderedAudio.length == 48000 else { fatalError("Audio duration changed") }
        let source = folder.appendingPathComponent("source.mov")
        let writer = try AVAssetWriter(outputURL: source, fileType: .mov)
        let track = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 240])
        let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: track, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240])
        writer.add(track); writer.startWriting(); writer.startSession(atSourceTime: .zero)
        for i in 0..<30 {
            while !track.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, 320, 240, kCVPixelFormatType_32ARGB, nil, &buffer)
            let context = CIContext()
            context.render(CIImage(color: CIColor(red: 0.2, green: 0.3, blue: 0.4)).cropped(to: CGRect(x: 0, y: 0, width: 320, height: 240)), to: buffer!)
            guard adapter.append(buffer!, withPresentationTime: CMTime(value: Int64(i), timescale: 30)) else { throw writer.error! }
        }
        track.markAsFinished(); await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error! }
        let model = await EditorModel()
        await model.loadVideo(source)
        let imported = await model.input
        guard imported == source else { fatalError("Valid video import failed") }
        let invalid = folder.appendingPathComponent("invalid.mp4")
        try Data("not a video".utf8).write(to: invalid)
        await model.loadVideo(invalid)
        let preserved = await model.input
        let errorStatus = await model.status
        guard preserved == source, errorStatus.hasPrefix("Could not open video:") else { fatalError("Invalid import was not handled safely") }
        print("PASS: valid video imports; invalid video reports an error and preserves the previous video.")
        guard let overlay = captionImage(text: "The reveal", size: CGSize(width: 320, height: 240)) else { fatalError("Caption image missing") }
        let asset = AVURLAsset(url: source)
        let video = AVVideoComposition(asset: asset) { request in request.finish(with: overlay.composited(over: request.sourceImage.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.06])), context: nil) }
        let output = folder.appendingPathComponent("output.mp4")
        try await exportAsset(asset, to: output, preset: AVAssetExportPresetHighestQuality, type: .mp4, video: video)
        let result = AVURLAsset(url: output)
        let duration = try await result.load(.duration)
        guard abs(duration.seconds - 1) < 0.1 else { fatalError("Export duration changed") }
        let image = try await AVAssetImageGenerator(asset: result).image(at: .zero).image
        guard image.width == 320, image.height == 240 else { fatalError("Export size changed") }
        print("PASS: audio EQ preserves duration; caption rasterizes; enhanced captioned MP4 exports and decodes at source size/duration.")
    }
}
