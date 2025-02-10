//
//  PlayerWidget.swift
//  VideoPlayer
//
//  Created by shayanbo on 2023/6/15.
//

import SwiftUI
import Combine

/// PlayerWidget 使用的服务
///
/// 此服务提供了一些应用于 PlayerWidget 的配置。
/// 开发者可以使用此服务来启用或禁用覆盖层，并添加自定义覆盖层。
/// 技术实现：使用 ObservableObject 和 @Published 实现响应式状态管理。
///
public class PlayerService: Service {
    
    // 渲染层之后的自定义覆盖层
    @Published fileprivate var overlayAfterRender:( ()->AnyView )?
    
    // 特性层之后的自定义覆盖层
    @Published fileprivate var overlayAfterFeature:( ()->AnyView )?
    
    // 插件层之后的自定义覆盖层
    @Published fileprivate var overlayAfterPlugin:( ()->AnyView )?
    
    // 控制层之后的自定义覆盖层
    @Published fileprivate var overlayAfterControl:( ()->AnyView )?
    
    // 提示层之后的自定义覆盖层
    @Published fileprivate var overlayAfterToast:( ()->AnyView )?
    
    // 当前启用的覆盖层集合
    @Published fileprivate var overlays = Overlay.allCases
    
    // 当前激活的特性
    @Published fileprivate var feature: FeatureService.Feature?
    
    // 用于存储 Combine 订阅的集合
    fileprivate var cancellables = [AnyCancellable]()
    
    public required init(_ context: Context) {
        super.init(context)
        
        // 订阅 FeatureService 的特性变化
        context[FeatureService.self].$feature.sink { [weak self] feature in
            self?.feature = feature
        }.store(in: &cancellables)
    }
    
    /// 用于其他 API 如 ``enable(overlays:)`` 或 ``configure(overlay:overlayGetter:)`` 的引用
    /// 技术实现：使用枚举定义内置覆盖层类型，支持 CaseIterable 协议实现遍历
    public enum Overlay: CaseIterable {
        
        /// 渲染层引用
        case render
        /// 特性层引用
        case feature
        /// 插件层引用
        case plugin
        /// 控制层引用
        case control
        /// 提示层引用
        case toast
    }
    
    /// 仅启用部分内置覆盖层
    ///
    /// 默认情况下，所有内置覆盖层都会添加到 PlayerWidget 中，
    /// 用户可以调用此方法来移除其中的一些覆盖层
    /// 技术实现：通过数组参数控制覆盖层的显示状态
    ///
    /// - Parameter overlays: 要添加的 ``Overlay`` 集合。未包含在集合中的覆盖层将不会添加到 PlayerWidget 中
    ///
    public func enable(overlays: [Overlay]) {
        self.overlays = overlays
    }
    
    /// 添加自定义覆盖层
    ///
    /// - Parameter overlay: 新覆盖层的位置，添加的覆盖层将显示在该位置之上
    /// - Parameter overlayGetter: 返回覆盖层实例的闭包
    /// 技术实现：使用闭包返回 AnyView 类型的视图，实现自定义覆盖层的动态注入
    ///
    public func configure(overlay: Overlay, overlayGetter: @escaping ()-> AnyView) {
        switch overlay {
        case .render:
            overlayAfterRender = overlayGetter
        case .feature:
            overlayAfterFeature = overlayGetter
        case .plugin:
            overlayAfterPlugin = overlayGetter
        case .control:
            overlayAfterControl = overlayGetter
        case .toast:
            overlayAfterToast = overlayGetter
        }
    }
}

/// VideoPlayerContainer 的主视图
///
/// 这是 VideoPlayerContainer 的入口，当开发者使用此框架时，首先要做的是创建 PlayerWidget，
/// 传入 Context 实例和可选的服务类型。
/// 创建时，它会根据需要添加内置覆盖层 [参见: ``PlayerService/enable(overlays:)``]，
/// 这些覆盖层都扮演着重要角色。覆盖层是具有不同规则的小部件容器。
///
/// 内置覆盖层的职责概述：
/// 1. Render: 控制播放和渲染细节
/// 2. Feature: 从4个方向弹出面板
/// 3. Plugin: 类似涂鸦墙，可以在特定位置呈现任何 ``Widget``
/// 4. Control: 这个覆盖层可能是你需要最关注的地方，它在固定位置显示小部件，如进度条、播放控件等
/// 5. Toast: 从左边缘飞入并在几秒钟后消失，开发者可以用它来显示一些提示或警告
///
/// 除了内置覆盖层外，开发者还可以插入自定义覆盖层来扩展 VideoPlayerContainer。
/// 参见 ``PlayerService/configure(overlay:overlayGetter:)``
/// 技术实现：基于 SwiftUI 的视图组合和布局系统，实现了多层次的 UI 叠加效果
///
public struct PlayerWidget: View {
    
    private weak var context: Context?
    
    /// PlayerWidget 的构造函数
    ///
    /// - Parameter context: 负责保存所有服务的 Context 实例
    /// - Parameter launch: 创建 PlayerWidget 时需要创建的可选服务集合
    /// - Returns: PlayerWidget 实例
    /// - Attention: PlayerWidget 不负责维护 Context 的生命周期。开发者应该承担这个责任。
    ///   例如，将其作为封闭视图中的 @StateObject 属性
    /// 技术实现：使用依赖注入模式，通过 Context 管理服务的生命周期
    ///
    public init(_ context: Context, launch services: [Service.Type] = []) {
        self.context = context
        
        services.forEach { serviceType in
            let _ = context[serviceType]
        }
    }
    
    public var body: some View {
        
        // 使用 GeometryReader 获取视图尺寸信息
        GeometryReader { proxy in
            
            let _ = {
                context?.viewSize.updateViewSize(proxy.size)
            }()
            
            // 使用 WithService 包装器获取 PlayerService 实例
            WithService(PlayerService.self) { service in
                
                HStack {
                    
                    // 左侧特性面板
                    if let feature = service.feature, case let .left(.squeeze(spacing)) = feature.direction {
                        
                        AnyView(
                            feature.content()
                                .frame(maxHeight: .infinity)
                                .transition(.move(edge: .leading))
                        )
                        
                        Spacer().frame(width: spacing)
                    }
                    
                    VStack {
                        
                        // 顶部特性面板
                        if let feature = service.feature, case let .top(.squeeze(spacing)) = feature.direction {
                            
                            AnyView(
                                feature.content()
                                    .frame(maxWidth: .infinity)
                                    .transition(.move(edge: .top))
                            )
                            
                            Spacer().frame(height: spacing)
                        }
                        
                        // 主要内容区域，使用 ZStack 实现覆盖层叠加
                        ZStack {
                            
                            // 渲染层
                            if service.overlays.contains(.render) {
                                RenderWidget()
                            }
                            
                            if let overlay = service.overlayAfterRender {
                                AnyView(overlay())
                            }
                            
                            // 特性层
                            if service.overlays.contains(.feature) {
                                FeatureWidget()
                            }
                            
                            if let overlay = service.overlayAfterFeature {
                                AnyView(overlay())
                            }
                            
                            // 插件层
                            if service.overlays.contains(.plugin) {
                                PluginWidget()
                            }
                            
                            if let overlay = service.overlayAfterPlugin {
                                AnyView(overlay())
                            }
                            
                            // 控制层
                            if service.overlays.contains(.control) {
                                ControlWidget()
                            }
                            
                            if let overlay = service.overlayAfterControl {
                                AnyView(overlay())
                            }
                            
                            // 提示层
                            if service.overlays.contains(.toast) {
                                ToastWidget()
                            }
                            
                            if let overlay = service.overlayAfterToast {
                                AnyView(overlay())
                            }
                        }
                        
                        // 底部特性面板
                        if let feature = service.feature, case let .bottom(.squeeze(spacing)) = feature.direction {
                            
                            Spacer().frame(height: spacing)
                            
                            AnyView(
                                feature.content()
                                    .frame(maxWidth: .infinity)
                                    .transition(.move(edge: .bottom))
                            )
                        }
                    }
                    
                    // 右侧特性面板
                    if let feature = service.feature, case let .right(.squeeze(spacing)) = feature.direction {
                        
                        Spacer().frame(width: spacing)
                        
                        AnyView(
                            feature.content()
                                .frame(maxHeight: .infinity)
                                .transition(.move(edge: .trailing))
                        )
                    }
                }
                .clipped()
            }
        }
        .environmentObject(context ?? Context())
        .coordinateSpace(name: CoordinateSpace.containerSpaceName)
        .onHover { changeOrEnd in
            context?.gesture.handleHover(action: changeOrEnd ? .start : .end)
        }
    }
}

public extension CoordinateSpace {
    
    fileprivate static var containerSpaceName: String {
        "PlayerWidget"
    }
    
    /// 容器范围的坐标空间
    ///
    /// 你可以在 GeometryProxy.frame(in:) 中使用它来访问整个 VideoPlayerContainer 中小部件的框架信息
    /// 技术实现：利用 SwiftUI 的坐标空间系统实现统一的布局参考系
    static var containerSpace: CoordinateSpace {
        .named(containerSpaceName)
    }
}

public extension Context {
    
    /// `context[PlayerService.self]` 的简单替代方案
    /// 技术实现：通过扩展提供便捷访问方式
    var container: PlayerService {
        self[PlayerService.self]
    }
}
