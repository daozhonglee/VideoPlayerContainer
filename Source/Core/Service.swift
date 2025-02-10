//
//  Service.swift
//  VideoPlayer
//
//  Created by shayanbo on 2023/6/22.
//

import Foundation
import SwiftUI
import Combine

/// Widget 实际上是 SwiftUI 的 View，它作为 VideoPlayerContainer 内部的可视化和交互组件。
///
/// 通常，VideoPlayerContainer 内部使用的大多数 Widget 都会有自己的 Service，并使用 ``WithService`` 作为其根视图来使用该服务。
/// 当你需要调用其他服务的 API 时，我们建议开发者使用自己的服务作为桥梁，而不是在 Widget 内部放置多个 WithService。
///
public typealias Widget = View

/// 其他服务的基类，它保持对其上下文的引用，以确保自定义服务可以访问其他服务。
///
/// 在 Service 内部，我们提供了一个有用的属性包装器：@``ViewState``。
/// @Published 用于触发 UI 更新机制，类似于 @State。
///
/// 技术实现：通过继承 ObservableObject 实现状态管理，使用弱引用持有 Context 实例
///
/// 有两种类型的 Service：
/// 1. **Widget Service**：
///     Widget Service 由特定的 Widget 使用。
///     它作为 ViewModel 使用，处理其 Widget 使用的所有逻辑。
///     它还负责与其他 Service 通信，因为有时 Widget 需要向外暴露一些供其他 Widget 使用的 API。
/// 2. **Non-Widget Service**：
///     Non-Widget Service 由其他 Service 使用。它作为一个公共服务，向外暴露供其他服务使用的 API。
///
open class Service : ObservableObject {

    public weak var context: Context?
    
    public required init(_ context: Context) {
        self.context = context
    }
}

/// WithService 用作 Widget 内部的根视图。
///
/// 技术实现：使用 SwiftUI 的环境对象和状态管理机制，实现服务的依赖注入和状态同步
///
/// 它提供两个功能：
/// 1. 由于 Widget Service 的角色之一是 ViewModel，因此将其作为根视图并调用服务的 API 来完成 Widget 的任务。
/// 2. 当服务的状态发生变化时，Widget 将触发 UI 更新机制。
///
public struct WithService<Content, S> : View where Content: View, S: Service {
    
    @EnvironmentObject private var context: Context
    
    @ViewBuilder private let content: (S) -> Content
    
    private let serviceType: S.Type
    
    public init(_ serviceType: S.Type, @ViewBuilder content: @escaping (S) -> Content) {
        self.content = content
        self.serviceType = serviceType
    }
    
    public var body: some View {
        _WithService(state: context[serviceType]) {
            content($0)
        }
    }
    
    private struct _WithService : View {
        
        @ObservedObject var state: S
        
        @ViewBuilder let content: (S) -> Content
        
        var body: some View {
            content(state)
        }
    }
}
