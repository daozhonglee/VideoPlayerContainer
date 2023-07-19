//
//  RenderWidget.swift
//  VideoPlayer
//
//  Created by shayanbo on 2023/6/15.
//

import Foundation
import SwiftUI
import AVKit
#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public class RenderService : Service {
    
    public let player = AVPlayer()
    
    public let layer = AVPlayerLayer()
    
    public func fill() {
        layer.videoGravity = .resizeAspectFill
    }
    
    public func fit() {
        layer.videoGravity = .resizeAspect
    }
}

struct RenderWidget : View {
    
    var body: some View {
        WithService(RenderService.self) { service in
            ZStack {
                RenderView(player: service.player, layer: service.layer)
                GestureWidget()
            }
        }
    }
}

#if os(iOS) || os(watchOS) || os(tvOS)

struct RenderView : UIViewRepresentable {

    let player: AVPlayer
    let layer: AVPlayerLayer
    
    func makeUIView(context: UIViewRepresentableContext<Self>) -> PlayerView {
        let playerView = PlayerView()
        playerView.playerLayer = layer
        playerView.player = player
        return playerView
    }

    func updateUIView(_ uiView: PlayerView, context: UIViewRepresentableContext<Self>) {
        
    }
}

class PlayerView: UIView {
    
    var videoGravity: AVLayerVideoGravity {
        get {
            let canvas = self.layer as! AVPlayerLayer
            return canvas.videoGravity
        }
        set {
            let canvas = self.layer as! AVPlayerLayer
            canvas.videoGravity = newValue
        }
    }
    
    var player: AVPlayer? {
        didSet {
            let canvas = self.layer.sublayers?.first as! AVPlayerLayer
            canvas.player = player
        }
    }
    
    var playerLayer: AVPlayerLayer? {
        didSet {
            self.layer.sublayers?.forEach {
                $0.removeFromSuperlayer()
            }
            guard let layer = playerLayer else {
                return
            }
            self.layer.addSublayer(layer)
            layer.frame = self.layer.bounds
        }
    }
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}

#elseif os(macOS)

struct RenderView : NSViewRepresentable {
    
    let player: AVPlayer
    let gravity: AVLayerVideoGravity
    
    func makeNSView(context: NSViewRepresentableContext<Self>) -> PlayerView {
        let playerView = PlayerView()
        playerView.player = player
        playerView.videoGravity = gravity
        return playerView
    }

    func updateNSView(_ uiView: PlayerView, context: NSViewRepresentableContext<Self>) {
        uiView.videoGravity = gravity
    }
}

class PlayerView: NSView {
    
    init() {
        super.init(frame: .zero)
        wantsLayer = true
    }
    
    override func makeBackingLayer() -> CALayer {
        AVPlayerLayer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var videoGravity: AVLayerVideoGravity {
        get {
            let canvas = self.layer as! AVPlayerLayer
            return canvas.videoGravity
        }
        set {
            let canvas = self.layer as! AVPlayerLayer
            canvas.videoGravity = newValue
        }
    }
    
    var player: AVPlayer? {
        didSet {
            let canvas = self.layer as! AVPlayerLayer
            canvas.player = player
        }
    }
}

#endif
