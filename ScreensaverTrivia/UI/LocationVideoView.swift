import SwiftUI
import AVFoundation
import UIKit

/// AVPlayerLayer keeps transport controls and file metadata out of the guessing UI.
struct LocationVideoView: UIViewRepresentable {
    let locationID: String
    var playing = true
    var resetKey: UUID?

    func makeUIView(context: Context) -> VideoSurface { VideoSurface() }
    func updateUIView(_ view: VideoSurface, context: Context) {
        view.configure(id: locationID, resetKey: resetKey, playing: playing)
    }
    static func dismantleUIView(_ view: VideoSurface, coordinator: ()) { view.stop() }
}

final class VideoSurface: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var locationID: String?
    private var resetKey: UUID?
    private let poster = UIImageView()
    private var observation: NSKeyValueObservation?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspectFill
        poster.contentMode = .scaleAspectFill
        poster.clipsToBounds = true
        addSubview(poster)
        isAccessibilityElement = true
        accessibilityLabel = "Location video. Choose one of the four place names."
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews(); poster.frame = bounds }

    func configure(id: String, resetKey: UUID?, playing: Bool) {
        if id != locationID || resetKey != self.resetKey {
            stop()
            locationID = id
            self.resetKey = resetKey
            poster.isHidden = false
            poster.image = LocationCatalog.mediaURL(id, extension: "jpg").flatMap { UIImage(contentsOfFile: $0.path) }
            guard let url = LocationCatalog.mediaURL(id, extension: "mp4") else { return }
            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer()
            queue.isMuted = true
            player = queue
            playerLayer.player = queue
            looper = AVPlayerLooper(player: queue, templateItem: item)
            observation = playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] layer, _ in
                DispatchQueue.main.async {
                    if layer.isReadyForDisplay { self?.poster.isHidden = true }
                }
            }
        }
        if playing { player?.play() } else { player?.pause() }
    }

    func stop() {
        observation?.invalidate()
        observation = nil
        player?.pause()
        looper?.disableLooping()
        looper = nil
        player?.removeAllItems()
        playerLayer.player = nil
        player = nil
        locationID = nil
        resetKey = nil
    }
}
