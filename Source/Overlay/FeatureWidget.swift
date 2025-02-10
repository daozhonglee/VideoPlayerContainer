//
//  FeatureWidget.swift
//  VideoPlayer
//
//  Created by shayanbo on 2023/6/15.
//

import SwiftUI
import Combine

/// FeatureWidget使用的服务
///
/// FeatureService用于在FeatureWidget中从4个方向弹出面板。
/// 技术实现：使用SwiftUI的动画系统和状态管理，实现面板的弹出和收起效果。
/// 
public class FeatureService : Service {
    
    struct Feature {
        let direction: Direction
        let content: ()->AnyView
        let action: Action
        
        struct Action {
            var beforePresent: ( ()->Void )?
            var afterPresent: ( ()->Void )?
            var beforeDismiss: ( ()->Void )?
            var afterDismiss: ( ()->Void )?
        }
    }
    
    @Published private(set) var feature: Feature?
    
    @Published fileprivate var dismissOnTap = true
    
    fileprivate var status: StatusService.Status?
    
    required init(_ context: Context) {
        super.init(context)
        context[StatusService.self].$status.sink(receiveValue: { [weak self] status in
            self?.status = status
        }).store(in: &cancellables)
    }
    
    fileprivate var dismissOnStatusChanged = true
    
    private var cancellables = [AnyCancellable]()
    
    /// 面板弹出的方向枚举
    /// 技术实现：使用嵌套枚举定义面板的展示方式和位置
    public enum Direction: Equatable {
        
        public enum Style: Equatable {
            /// 面板覆盖在其他视图之上，不影响其他视图
            case cover
            /// 面板通过挤压渲染视图的空间来展示
            case squeeze(CGFloat)
        }
        
        case left(Style)
        case right(Style)
        case top(Style)
        case bottom(Style)
    }
    
    /// 配置点击是否会关闭面板
    /// 技术实现：通过布尔值控制面板的交互行为
    /// - Parameter dismissOnTap: 布尔值，指示点击是否会关闭面板
    ///
    public func configure(dismissOnTap: Bool) {
        self.dismissOnTap = dismissOnTap
    }
    
    /// 配置状态改变是否会关闭面板
    /// 技术实现：通过布尔值控制面板对状态变化的响应
    /// - Parameter dismissOnStatusChanged: 布尔值，指示状态改变是否会关闭面板
    ///
    public func configure(dismissOnStatusChanged: Bool) {
        self.dismissOnStatusChanged = dismissOnStatusChanged
    }
    
    /// 从指定方向弹出面板
    /// 技术实现：使用SwiftUI的动画系统和回调机制，实现面板的生命周期管理
    ///
    /// - Parameters:
    ///     - direction: 面板从此方向飞入
    ///     - animation: 面板展示时应用的动画
    ///     - beforePresent: 面板展示前执行的动作
    ///     - afterPresent: 面板展示后执行的动作
    ///     - beforeDismiss: 面板关闭前执行的动作
    ///     - afterDismiss: 面板关闭后执行的动作
    ///     - content: 创建面板内容的视图构建器
    ///
    public func present(
        _ direction: Direction,
        animation: Animation? = .default,
        beforePresent: ( ()->Void )? = nil,
        afterPresent: ( ()->Void )? = nil,
        beforeDismiss: ( ()->Void )? = nil,
        afterDismiss: ( ()->Void )? = nil,
        content: @escaping ()-> AnyView
    ){  
        let action = Feature.Action(
            beforePresent: beforePresent,
            afterPresent: afterPresent,
            beforeDismiss: beforeDismiss,
            afterDismiss: afterDismiss
        )
        let feature = Feature(direction: direction, content: content, action: action)
        
        feature.action.beforePresent?()
        
        withAnimation(animation) {
            self.feature = feature
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
            self?.feature?.action.afterPresent?()
        }
    }
    
    /// 关闭当前展示的面板
    /// 技术实现：使用SwiftUI的动画系统实现平滑的关闭效果
    /// - Parameter animation: 面板关闭时应用的动画
    ///
    public func dismiss(animation: Animation? = .default) {
        let action = feature?.action
        
        action?.beforeDismiss?()
        
        withAnimation(animation) {
            feature = nil
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) {
            action?.afterDismiss?()
        }
    }
}

/// 特性组件
/// 技术实现：使用SwiftUI的ZStack和条件渲染，实现多方向面板的展示
struct FeatureWidget: View {
    
    var body: some View {
        
        WithService(FeatureService.self) { service in
            ZStack {
                
                if service.feature != nil {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture {
                            if service.dismissOnTap {
                                service.dismiss()
                            }
                        }
                }
                
                VStack(alignment: .leading) {
                    Spacer()
                        .frame(maxWidth: .infinity, maxHeight: 0)
                    if let feature = service.feature, feature.direction == .left(.cover) {
                        AnyView(
                            feature.content()
                                .frame(maxHeight: .infinity)
                                .transition(.move(edge: .leading))
                        )
                    }
                }
                
                VStack(alignment: .trailing) {
                    Spacer()
                        .frame(maxWidth: .infinity, maxHeight: 0)
                    if let feature = service.feature, feature.direction == .right(.cover) {
                        AnyView(
                            feature.content()
                                .frame(maxHeight: .infinity)
                                .transition(.move(edge: .trailing))
                        )
                    }
                }
                
                VStack {
                    if let feature = service.feature, feature.direction == .top(.cover) {
                        AnyView(
                            feature.content()
                                .frame(maxWidth: .infinity)
                                .transition(.move(edge: .top))
                        )
                    }
                    Spacer()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                VStack {
                    Spacer()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if let feature = service.feature, feature.direction == .bottom(.cover) {
                        AnyView(
                            feature.content()
                                .frame(maxWidth: .infinity)
                                .transition(.move(edge: .bottom))
                        )
                    }
                }
            }
            .onChange(of: service.status) { _ in
                if service.dismissOnStatusChanged {
                    service.dismiss()
                }
            }
        }
    }
}

public extension Context {
    
    /// `context[FeatureService.self]` 的简单替代方案
    /// 技术实现：通过扩展提供便捷访问方式
    var feature: FeatureService {
        self[FeatureService.self]
    }
}
