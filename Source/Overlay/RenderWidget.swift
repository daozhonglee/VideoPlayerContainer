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

/// RenderWidget使用的服务。
///
/// RenderService提供AVPlayer来控制播放，以及AVPlayerLayer来控制渲染细节。
/// 它还支持更改默认的AVPlayer。通过这种方式，你可以将AVPlayer从一个Context传递到另一个Context。
/// 技术实现：使用AVFoundation框架的核心组件，结合SwiftUI的视图封装，实现跨平台的视频渲染功能。
/// 采用依赖注入方式实现播放器实例的灵活切换。
///
public class RenderService : Service {
    
    /// AVPlayer实例
    /// 技术实现：使用AVPlayer作为核心播放引擎
    public private(set) var player = AVPlayer()
    
    /// AVPlayerLayer实例
    /// 技术实现：使用AVPlayerLayer处理视频渲染层
    public let layer = AVPlayerLayer()
    
    /// 切换到另一个AVPlayer实例
    /// 技术实现：通过依赖注入模式实现播放器实例的动态切换
    /// - Parameter player: AVPlayer实例
    ///
    public func attach(player: AVPlayer) {
        self.player = player
        layer.player = player
    }
}

/// 渲染组件
/// 技术实现：使用SwiftUI的视图组合，将AVPlayer的渲染层与手势层组合在一起
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

/// iOS平台的渲染视图
/// 技术实现：使用UIViewRepresentable协议将UIKit视图封装到SwiftUI中
fileprivate struct RenderView : UIViewRepresentable {

    let player: AVPlayer
    let layer: AVPlayerLayer
    
    func makeUIView(context: UIViewRepresentableContext<Self>) -> PlayerView {
        let playerView = PlayerView()
        playerView.playerLayer = layer
        playerView.player = player
        return playerView
    }

    func updateUIView(_ uiView: PlayerView, context: UIViewRepresentableContext<Self>) { }
}

/// iOS平台的播放器视图
/// 技术实现：自定义UIView，管理AVPlayerLayer的生命周期和布局
fileprivate class PlayerView: UIView {
    
    var player: AVPlayer? {
        didSet {
            if let canvas = self.layer.sublayers?.first as? AVPlayerLayer {
                canvas.player = player
            }
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
            layer.player = player
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = self.bounds
    }
    
    deinit {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
}

#elseif os(macOS)

/// macOS平台的渲染视图
/// 技术实现：使用NSViewRepresentable协议将AppKit视图封装到SwiftUI中
fileprivate struct RenderView : NSViewRepresentable {
    
    let player: AVPlayer
    let layer: AVPlayerLayer
    
    func makeNSView(context: NSViewRepresentableContext<Self>) -> PlayerView {
        let playerView = PlayerView()
        playerView.player = player
        playerView.playerLayer = layer
        return playerView
    }

    func updateNSView(_ uiView: PlayerView, context: NSViewRepresentableContext<Self>) { }
}

/// macOS平台的播放器视图
/// 技术实现：自定义NSView，管理AVPlayerLayer的生命周期和布局
fileprivate class PlayerView: NSView {
    
    init() {
        super.init(frame: .zero)
        wantsLayer = true
    }
    
    override func makeBackingLayer() -> CALayer {
        CALayer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var player: AVPlayer? {
        didSet {
            if let canvas = self.layer?.sublayers?.first as? AVPlayerLayer {
                canvas.player = player
            }
        }
    }
    
    var playerLayer: AVPlayerLayer? {
        didSet {
            self.layer?.sublayers?.forEach {
                $0.removeFromSuperlayer()
            }
            guard let layer = playerLayer else {
                return
            }
            self.layer?.addSublayer(layer)
            layer.player = player
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        }
    }
    
    deinit {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
}

#endif

public extension Context {
    
    /// `context[RenderService.self]` 的简单替代方案
    /// 技术实现：通过扩展提供便捷访问方式
    var render: RenderService {
        self[RenderService.self]
    }
}
