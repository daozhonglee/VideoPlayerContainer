//
//  PluginWidget.swift
//  VideoPlayer
//
//  Created by shayanbo on 2023/6/19.
//

import SwiftUI
import Combine

/// PluginWidget 使用的服务。
///
/// 类似涂鸦墙，你可以在特定位置呈现任何 ``Widget``。
/// 技术实现：使用 SwiftUI 的视图系统和动画框架，实现灵活的插件展示机制。
/// 
public class PluginService : Service {
    
    fileprivate struct Plugin {
        let alignment: Alignment
        let transition: AnyTransition
        let content: ()->AnyView
    }
    
    /// 表示插件是否正在展示的布尔值
    /// 技术实现：通过检查 plugin 属性是否为 nil 来判断插件状态
    public var isBeingPresented: Bool {
        plugin != nil
    }
    
    @Published fileprivate var plugin: Plugin?
    
    /// 展示插件小部件
    /// 
    /// - Parameter alignment: 用于在 x 轴和 y 轴上对齐插件的指南。
    /// - Parameter animation: 展示插件时应用的动画。
    /// - Parameter transition: 展示和关闭插件时应用的过渡效果。
    /// - Parameter content: 用于创建插件小部件的视图构建器。
    /// 技术实现：使用 SwiftUI 的动画和过渡系统实现流畅的插件展示效果。
    ///
    public func present(_ alignment: Alignment, animation: Animation? = .default, transition: AnyTransition = .opacity, content: @escaping ()-> AnyView) {
        withAnimation(animation) {
            self.plugin = Plugin(alignment: alignment, transition: transition, content: content)
        }
    }
    
    /// 关闭插件小部件
    /// - Parameter animation: 关闭插件时应用的动画。
    /// 技术实现：使用 SwiftUI 的动画系统实现平滑的关闭效果。
    ///
    public func dismiss(animation: Animation? = .default) {
        withAnimation(animation) {
            self.plugin = nil
        }
    }
}

struct PluginWidget: View {
    var body: some View {
        WithService(PluginService.self) { service in
            
            ZStack(alignment: service.plugin?.alignment ?? .center) {
                Spacer().frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if let plugin = service.plugin {
                    plugin.content()
                        .transition(plugin.transition)
                }
            }
        }
    }
}

public extension Context {
    
    /// `context[PluginService.self]` 的简单替代方案
    /// 技术实现：通过扩展提供便捷访问方式
    var plugin: PluginService {
        self[PluginService.self]
    }
}
