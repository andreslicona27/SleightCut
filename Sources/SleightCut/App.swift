import SwiftUI
import AVKit
import UniformTypeIdentifiers

extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255)/255, green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255, opacity: 1) }
    static let deepRed = Color(hex: 0x9B1E22), darkRed = Color(hex: 0x6F0D13)
    static let ink = Color(hex: 0x010101), surface = Color(hex: 0x060202), burgundy = Color(hex: 0x0E0505), crimson = Color(hex: 0xDB2B33), bright = Color(hex: 0xFC4447), paper = Color(hex: 0xFCF3F2), muted = Color(hex: 0xAB9A99)
}
// Georgia is the website's installed-font fallback for Cormorant Garamond.
extension Font {
    static func display(_ size: CGFloat) -> Font { .custom("Georgia", size: size) }
}
struct BrandButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 18).padding(.vertical, 13)
            .foregroundStyle(Color.paper)
            .background {
                RoundedRectangle(cornerRadius: 7).fill(primary
                    ? LinearGradient(colors: [.crimson, .deepRed], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [.crimson.opacity(configuration.isPressed ? 0.16 : 0.04)], startPoint: .top, endPoint: .bottom))
            }
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.crimson.opacity(primary ? 0.3 : 0.4)))
            .shadow(color: primary ? .crimson.opacity(0.2) : .clear, radius: 18, y: 4)
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}
struct StudioPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(22).background(Color.surface.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.darkRed.opacity(0.48)))
    }
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 10, weight: .medium)).tracking(2.6).foregroundStyle(Color.crimson) }
}
@main struct SleightCutApp: App {
    var body: some Scene {
        WindowGroup {
            EditorView().frame(minWidth: 1060, minHeight: 760).preferredColorScheme(.dark)
        }.windowStyle(.hiddenTitleBar).defaultSize(width: 1240, height: 900)
    }
}
struct EditorView: View {
    @StateObject private var model = EditorModel()
    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    introduction
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 20) { preview; captionEditor }.frame(maxWidth: .infinity)
                        controls.frame(width: 290)
                    }
                    exportBar
                    HStack {
                        Text("THIBAULT DI MARIA").tracking(2)
                        Spacer()
                        Text("The performance lives on.").font(.display(14)).italic()
                    }.font(.system(size: 9)).foregroundStyle(Color.muted.opacity(0.7)).padding(.top, 2)
                }.padding(32).frame(maxWidth: 1440).frame(maxWidth: .infinity)
            }
        }
        .background {
            ZStack {
                Color.ink
                GeometryReader { geometry in
                    Ellipse().fill(Color.deepRed.opacity(0.22)).frame(width: 700, height: 450).blur(radius: 110).offset(x: -160, y: 20)
                    Ellipse().fill(Color.darkRed.opacity(0.18)).frame(width: 550, height: 550).blur(radius: 120).offset(x: geometry.size.width - 400, y: 350)
                }.clipped()
            }
        }.foregroundStyle(Color.paper).tint(.crimson)
    }
    private var header: some View {
        HStack(spacing: 20) {
            Text("THDM").font(.display(29)).tracking(4).foregroundStyle(Color.crimson)
            Rectangle().fill(Color.darkRed.opacity(0.6)).frame(width: 1, height: 24)
            Text("SleightCut").font(.display(21))
            Spacer()
            Text("THE EDITING STUDIO").font(.system(size: 10)).tracking(2).foregroundStyle(Color.muted)
            Text("DESKTOP").font(.system(size: 9)).tracking(1.4).padding(.horizontal, 12).padding(.vertical, 7)
                .overlay(Capsule().stroke(Color.crimson.opacity(0.35))).foregroundStyle(Color.crimson)
        }.padding(.horizontal, 32).padding(.top, 22).padding(.bottom, 18)
            .background(Color.ink.opacity(0.8))
            .overlay(alignment: .bottom) { Rectangle().fill(Color.darkRed.opacity(0.45)).frame(height: 1) }
    }
    private var introduction: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) { Image(systemName: "sparkles"); Text("A LITTLE MAGIC. A LASTING IMPRESSION.").tracking(2) }
                    .font(.system(size: 9)).foregroundStyle(Color.crimson)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.crimson.opacity(0.08)).clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.crimson.opacity(0.3)))
                Text("Make the moment unforgettable.").font(.display(40)).tracking(-1)
                    .foregroundStyle(LinearGradient(colors: [.paper, Color(hex: 0xC6AAA8)], startPoint: .top, endPoint: .bottom))
                Text("Refine your film. Let the magic speak.").font(.system(size: 14)).foregroundStyle(Color.muted)
            }
            Spacer(minLength: 16)
            Text("♠").font(.display(74)).foregroundStyle(Color.crimson.opacity(0.18)).rotationEffect(.degrees(12)).accessibilityHidden(true)
        }
    }
    private var preview: some View {
        StudioPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Eyebrow(text: "01 / YOUR PERFORMANCE"); Spacer(); Text(model.input == nil ? "NO VIDEO SELECTED" : "VIDEO LOADED").font(.system(size: 9)).tracking(1).foregroundStyle(Color.muted) }
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Color.ink)
                    if let player = model.player {
                        NativeVideoPreview(player: player).clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        VStack(spacing: 14) {
                            Image(systemName: "play").font(.system(size: 23, weight: .light)).foregroundStyle(Color.crimson)
                                .frame(width: 62, height: 62).background(Color.crimson.opacity(0.08)).clipShape(Circle())
                                .overlay(Circle().stroke(Color.crimson.opacity(0.35)))
                                .shadow(color: .bright.opacity(0.12), radius: 24)
                            Text("Every great trick deserves a great film.").font(.display(23))
                            Text("Choose a video to begin your edit.").font(.system(size: 12)).foregroundStyle(Color.muted)
                            Button(action: model.chooseVideo) { Label("Choose a video", systemImage: "plus") }.buttonStyle(BrandButtonStyle(primary: true)).disabled(model.busy)
                        }.padding(24)
                    }
                }.frame(height: 280)
                HStack {
                    Image(systemName: "film").foregroundStyle(Color.crimson)
                    Text(model.input?.lastPathComponent ?? "MOV, MP4 & Mac-compatible video").lineLimit(1).truncationMode(.middle)
                    Spacer()
                    if model.input != nil { Button("Change video", action: model.chooseVideo).buttonStyle(.plain).foregroundStyle(Color.crimson).disabled(model.busy) }
                }.font(.system(size: 11)).foregroundStyle(Color.muted)
            }
        }
    }
    private var controls: some View {
        StudioPanel {
            VStack(alignment: .leading, spacing: 18) {
                Eyebrow(text: "02 / THE FINISHING TOUCHES")
                Text("Refine the reveal.").font(.display(27))
                option("Picture enhancement", icon: "wand.and.stars", detail: "Subtle contrast, color and sharpening at the original resolution.", value: $model.enhance)
                rule
                option("Speech clarity", icon: "waveform", detail: "Reduces rumble and high-frequency noise. Other speakers remain audible.", value: $model.cleanAudio)
                rule
                option("Conversation captions", icon: "captions.bubble", detail: "Burn your reviewed captions into the finished film.", value: $model.captionsEnabled)
                Picker("Language", selection: $model.language) {
                    Text("English").tag("en-US"); Text("Spanish").tag("es-ES"); Text("French").tag("fr-FR")
                }.font(.system(size: 12))
                Button(action: model.transcribe) { HStack { Text("Generate captions"); Spacer(); Image(systemName: "arrow.right") } }.buttonStyle(BrandButtonStyle()).disabled(model.input == nil)
                Text("On-device Apple Speech requires a compatible downloaded language model.").font(.system(size: 10)).foregroundStyle(Color.muted).lineSpacing(3)
            }.disabled(model.busy)
        }
    }
    private func option(_ title: String, icon: String, detail: String, value: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: icon).foregroundStyle(Color.crimson).frame(width: 18)
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer(minLength: 4)
                Toggle(title, isOn: value).labelsHidden().toggleStyle(.switch).controlSize(.mini)
            }
            Text(detail).font(.system(size: 11)).foregroundStyle(Color.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var rule: some View { Rectangle().fill(Color.darkRed.opacity(0.35)).frame(height: 1) }
    private var captionEditor: some View {
        StudioPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Eyebrow(text: "03 / THE CONVERSATION"); Spacer(); Text("TIMING IN SECONDS").font(.system(size: 9)).tracking(1).foregroundStyle(Color.muted) }
                if model.captions.isEmpty {
                    HStack(spacing: 14) {
                        Image(systemName: "text.quote").font(.system(size: 24, weight: .light)).foregroundStyle(Color.crimson.opacity(0.7))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Give the moment a voice.").font(.display(21))
                            Text("Generate captions to edit the dialogue, or export without them.").font(.system(size: 11)).foregroundStyle(Color.muted)
                        }
                        Spacer()
                    }.padding(.vertical, 9)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach($model.captions) { $caption in
                                HStack {
                                    TextField("Start", value: $caption.start, format: .number).frame(width: 52).accessibilityLabel("Caption start in seconds")
                                    Text("–").foregroundStyle(Color.muted)
                                    TextField("End", value: $caption.end, format: .number).frame(width: 52).accessibilityLabel("Caption end in seconds")
                                    TextField("Caption", text: $caption.text)
                                    Button { model.captions.removeAll { $0.id == caption.id } } label: { Image(systemName: "trash") }.buttonStyle(.plain).foregroundStyle(Color.muted).help("Delete caption")
                                }.font(.system(size: 12)).textFieldStyle(.roundedBorder)
                            }
                        }
                    }.frame(height: 130).disabled(model.busy)
                }
            }
        }
    }
    private var exportBar: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.status).font(.system(size: 12)).foregroundStyle(Color.paper).textSelection(.enabled)
                Text("Warm-white captions · crimson accents · original aspect ratio").font(.system(size: 10)).foregroundStyle(Color.muted)
            }
            if model.busy { ProgressView().controlSize(.small) }
            Spacer(minLength: 8)
            if let output = model.output { Button("Show export") { NSWorkspace.shared.activateFileViewerSelecting([output]) }.buttonStyle(BrandButtonStyle()) }
            Button(action: model.exportVideo) { HStack(spacing: 16) { Text("Export your film"); Image(systemName: "arrow.right") } }.buttonStyle(BrandButtonStyle(primary: true)).disabled(model.input == nil || model.busy)
        }.padding(.top, 6)
    }
}
