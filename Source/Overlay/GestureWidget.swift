//
//  GestureWidget.swift
//  VideoPlayer
//
//  Created by shayanbo on 2023/6/26.
//

import SwiftUI
import Combine

/// GestureWidget 使用的服务。
///
/// GestureService 提供多种手势支持：点击、双击、拖拽、长按、旋转、缩放和悬停。
/// 其他服务可以通过 observe 方法轻松地将动作绑定到手势上。
/// 对于某些手势，用户可以通过指定位置来观察它们。例如，点击手势可以区分左右位置。
///
public class GestureService : Service {
    
    /// 标志位，用于确定内置手势是否启用或禁用
    @Published public private(set) var enabled = true
    
    /// 启用或禁用全部内置手势支持
    /// - Parameter onOrOff: 标志位，用于确定内置手势是否启用或禁用
    ///
    public func configure(_ onOrOff: Bool) {
        self.enabled = onOrOff
    }
    
    //MARK: 手势观察
    
    public enum Gesture: Equatable {

        public enum Location: Equatable {
            case all, left, right
            
            public static func == (a: Location, b: Location) -> Bool {
                switch (a, b) {
                case (.all, _), (_, .all): return true
                case (.left, .right), (.right, .left): return false
                default: return true
                }
            }
        }

        public enum Direction: Equatable {
            case horizontal, vertical(Location)
        }

        case tap(Location)
        case doubleTap(Location)
        case drag(Direction)
        case longPress
        case rotate
        case pinch
        case hover
    }
    
    private let observable = PassthroughSubject<GestureEvent, Never>()
    
    /// 当手势事件发生时用户接收到的手势信息
    public struct GestureEvent {
        
        public enum Action {
            case start, end
        }
        
        public enum Value {
            case tap(CGPoint)
            case doubleTap(CGPoint)
            case drag(DragGesture.Value)
            case longPress
            case rotate(RotationGesture.Value)
            case pinch(MagnificationGesture.Value)
            case hover
        }
        
        public let gesture: Gesture
        public let action: Action
        public let value: Value
    }
    
    /// 观察特定手势并绑定动作
    /// - Parameters:
    ///     - gesture: 要观察的手势
    ///     - handler: 当特定手势发生时要执行的动作
    ///
    public func observe(_ gesture: Gesture, handler: @escaping (GestureEvent)->Void) -> AnyCancellable {
        observable.filter { event in
            event.gesture == gesture
        }.sink { event in
            handler(event)
        }
    }
    
    //MARK: 同步手势
    
    /// 拖拽手势
    /// 应用于整个 VideoPlayerContainer 的手势应该分配给此属性以确保你能接收到事件
    @Published public var simultaneousDragGesture: _EndedGesture<_ChangedGesture<DragGesture>>?
    
    /// 点击手势
    /// 应用于整个 VideoPlayerContainer 的手势应该分配给此属性以确保你能接收到事件
    @Published public var simultaneousTapGesture: _EndedGesture<SpatialTapGesture>?

    /// 双击手势
    /// 应用于整个 VideoPlayerContainer 的手势应该分配给此属性以确保你能接收到事件
    @Published public var simultaneousDoubleTapGesture: _EndedGesture<SpatialTapGesture>?
    
    /// 长按手势
    /// 应用于整个 VideoPlayerContainer 的手势应该分配给此属性以确保你能接收到事件
    @Published public var simultaneousLongPressGesture: _EndedGesture<LongPressGesture>?
    
    /// 缩放手势
    /// 应用于整个 VideoPlayerContainer 的手势应该分配给此属性以确保你能接收到事件
    @Published public var simultaneousPinchGesture: _EndedGesture<_ChangedGesture<MagnificationGesture>>?
    
    /// 旋转手势
    /// 应用于整个 VideoPlayerContainer 的手势应该分配给此属性以确保你能接收到事件
    @Published public var simultaneousRotationGesture: _EndedGesture<_ChangedGesture<RotationGesture>>?
    
    //MARK: 手势实现
    
    /// 点击手势
    /// 技术实现：使用 SpatialTapGesture 识别单次点击，并根据点击位置判断左右区域
    public private(set) lazy var tapGesture: some SwiftUI.Gesture = {
        SpatialTapGesture(count: 1)
            .onEnded { [weak self] value in
                guard let self, let context else { return }
                let leftSide = value.location.x < context.viewSize.width * 0.5
                let event = GestureEvent(gesture: .tap( leftSide ? .left : .right ), action: .end, value: .tap(value.location))
                self.observable.send(event)
            }
    }()

    /// 双击手势
    /// 技术实现：使用 SpatialTapGesture 识别双击，并根据点击位置判断左右区域
    public private(set) lazy var doubleTapGesture: some SwiftUI.Gesture = {
        SpatialTapGesture(count: 2)
            .onEnded { [weak self] value in
                guard let self, let context else { return }
                let leftSide = value.location.x < context.viewSize.width * 0.5
                let event = GestureEvent(gesture: .doubleTap( leftSide ? .left : .right ), action: .end, value: .doubleTap(value.location))
                self.observable.send(event)
            }
    }()
    
    /// 长按手势
    /// 技术实现：使用 LongPressGesture 识别长按动作，发送长按事件
    public private(set) lazy var longPressGesture: some SwiftUI.Gesture = {
        LongPressGesture()
            .onEnded { [weak self] value in
                guard let self else { return }
                let event = GestureEvent(gesture: .longPress, action: .end, value: .longPress)
                self.observable.send(event)
            }
    }()
    
    /// 拖拽手势
    /// 技术实现：使用 DragGesture 识别拖拽，通过计算拖拽方向和起始位置来判断手势类型
    public private(set) lazy var dragGesture: some SwiftUI.Gesture = {
        
        let handleDrag: (DragGesture.Value, GestureEvent.Action)->Void = { [weak self] value, action in
            guard let self, let context else { return }
            
            let direction: Gesture.Direction = {
                
                if let last = self.lastDragGesture, case let .drag(direction) = last.gesture {
                    return direction
                }
                
                let horizontal = abs(value.translation.width) > abs(value.translation.height)
                if horizontal {
                    return .horizontal
                }
                let leftSide = value.startLocation.x < context.viewSize.width * 0.5
                if leftSide {
                    return .vertical(.left)
                } else {
                    return .vertical(.right)
                }
            }()
            
            let event = GestureEvent(gesture: .drag(direction), action: action, value: .drag(value))
            
            switch action {
            case .start:
                if self.lastDragGesture == nil {
                    self.lastDragGesture = event
                }
            case .end:
                self.lastDragGesture = nil
            }
            self.observable.send(event)
        }
        
        return
            DragGesture()
                .onChanged{ value in
                    handleDrag(value, .start)
                }
                .onEnded{ value in
                    handleDrag(value, .end)
                }
        
    }()
    
    /// 缩放手势
    /// 技术实现：使用 MagnificationGesture 识别缩放动作，处理缩放开始和结束事件
    public private(set) lazy var pinchGesture: some SwiftUI.Gesture = {
        MagnificationGesture()
            .onChanged { [weak self] value in
                guard let self else { return }
                let event = GestureEvent(gesture: .pinch, action: .start, value: .pinch(value))
                self.observable.send(event)
            }
            .onEnded { [weak self] value in
                guard let self else { return }
                let event = GestureEvent(gesture: .pinch, action: .end, value: .pinch(value))
                self.observable.send(event)
            }
    }()

    /// 旋转手势
    /// 技术实现：使用 RotationGesture 识别旋转动作，处理旋转开始和结束事件
    public private(set) lazy var rotationGesture: some SwiftUI.Gesture = {
        RotationGesture()
            .onChanged { [weak self] value in
                guard let self else { return }
                let event = GestureEvent(gesture: .rotate, action: .start, value: .rotate(value))
                self.observable.send(event)
            }
            .onEnded { [weak self] value in
                guard let self else { return }
                let event = GestureEvent(gesture: .rotate, action: .end, value: .rotate(value))
                self.observable.send(event)
            }
    }()
    
    private var lastDragGesture: GestureEvent?
    
    func handleHover(action: GestureEvent.Action) {
        let event = GestureEvent(gesture: .hover, action: action, value: .hover)
        observable.send(event)
    }
}

/// 手势组件
/// 技术实现：使用 SwiftUI 的手势系统，通过 SimultaneousGesture 组合多个手势，实现复杂的交互功能
struct GestureWidget: View {
    var body: some View {
        WithService(GestureService.self) { service in
            if service.enabled {
                Color.clear.contentShape(Rectangle())
                    .gesture(
                        SimultaneousGesture(
                            service.doubleTapGesture,
                            service.simultaneousDoubleTapGesture ?? SpatialTapGesture(count:2).onEnded { _ in }
                        )
                    )
                    .gesture(
                        SimultaneousGesture(
                            service.tapGesture,
                            service.simultaneousTapGesture ?? SpatialTapGesture(count:1).onEnded { _ in }
                        )
                    )
                    .gesture(
                        SimultaneousGesture(
                            service.longPressGesture,
                            service.simultaneousLongPressGesture ?? LongPressGesture().onEnded{_ in }
                        )
                    )
                    .gesture(
                        SimultaneousGesture(
                            service.dragGesture,
                            service.simultaneousDragGesture ?? DragGesture().onChanged{_ in}.onEnded{_ in}
                        )
                    )
                    .gesture(
                        SimultaneousGesture(
                            service.pinchGesture,
                            service.simultaneousPinchGesture ?? MagnificationGesture().onChanged{_ in}.onEnded{_ in}
                        )
                    )
                    .gesture(
                        SimultaneousGesture(
                            service.rotationGesture,
                            service.simultaneousRotationGesture ?? RotationGesture().onChanged{_ in}.onEnded{_ in}
                        )
                    )
            }
        }
    }
}

public extension Context {
    
    /// `context[GestureService.self]` 的简单替代方案
    var gesture: GestureService {
        self[GestureService.self]
    }
}
