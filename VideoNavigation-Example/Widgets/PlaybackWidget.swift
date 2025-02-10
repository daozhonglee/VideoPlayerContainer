//
//  PlaybackWidget.swift
//  VideoPlayer
//
//  Created by shayanbo on 2023/6/19.
//

import SwiftUI
import Combine
import VideoPlayerContainer

/// 播放控制组件的服务类
/// 技术实现：使用 KVO 监听播放器状态，实现播放/暂停控制
fileprivate class PlaybackWidgetService: Service {
    
    /// 播放速率观察器
    /// 技术实现：使用 KVO 监听 AVPlayer 的播放速率变化
    private var rateObservation: NSKeyValueObservation?
    
    /// 播放状态观察器
    /// 技术实现：使用 KVO 监听 AVPlayer 的播放状态变化
    private var statusObservation: NSKeyValueObservation?
    
    /// 用于存储 Combine 订阅的集合
    /// 技术实现：使用 Combine 框架管理订阅的生命周期
    private var cancellables = [AnyCancellable]()
    
    /// 播放状态标志
    /// 技术实现：使用 @Published 实现状态的响应式更新
    @Published var playOrPaused = false
    
    /// 是否可点击的状态标志
    /// 技术实现：使用 @Published 实现状态的响应式更新
    @Published var clickable = false
    
    required init(_ context: Context) {
        super.init(context)
        
        rateObservation = context.render.player.observe(\.rate, options: [.old, .new, .initial]) { [weak self] player, change in
            self?.playOrPaused = player.rate > 0
        }
        
        statusObservation = context.render.player.observe(\.status, options: [.old, .new, .initial]) { [weak self] player, change in
            self?.clickable = player.status == .readyToPlay
        }
        
        context.gesture.observe(.doubleTap(.all)) { [weak self] _ in
            self?.didClick()
        }.store(in: &cancellables)
    }
    
    func didClick() {
        guard let context else { return }
        if context.render.player.rate == 0 {
            context.render.player.play()
        } else {
            context.render.player.pause()
        }
    }
}

/// 播放控制组件
/// 技术实现：使用 SwiftUI 实现播放/暂停按钮的 UI 和交互
struct PlaybackWidget : View {
    
    var body: some View {
        WithService(PlaybackWidgetService.self) { service in
            Group {
                if service.playOrPaused {
                    Image(systemName: "pause.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "play.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .foregroundColor(.white)
                }
            }
            .onTapGesture {
                service.didClick()
            }
        }
    }
}
