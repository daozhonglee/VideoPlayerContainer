//
//  Context.swift
//  VideoPlayer
//
//  Created by shayanbo on 2023/6/22.
//

import Foundation

/// Context 是核心概念，作为一个中心枢纽，可以被所有 ``Service`` 和 ``Widget`` 访问。
///
/// 它维护着一个服务定位器，开发者可以通过它获取其他 Service，而无需事先注册。
/// 它还维护着一个 dependencyValues，用于保存从该 Context 获取的服务所使用的所有外部依赖。
/// 通常，Context 的生命周期与其所在的底层视图相同。
///
/// 技术实现：使用 ObservableObject 协议实现状态管理，通过递归锁确保线程安全，采用字典存储服务实例
///
public class Context : ObservableObject {
    
    public init() {}
    
    fileprivate let lock = NSRecursiveLock()
    
    fileprivate var services = [String: Service]()
    
    /// 通过类型获取服务实例。
    ///
    /// 该方法作为一个特殊的服务定位器，具有特定的缓存策略，开发者无需事先注册即可获取服务。
    /// 它接受 Service.Type 作为输入，并根据需要返回服务实例，确保每个 ``Service`` 类型在一个 Context 实例中最多只有一个实例。
    /// 此外，当你不再需要时，可以通过 ``stopService(_:)`` 停止它。
    ///
    /// 技术实现：使用类型名作为键，实现服务的单例模式和懒加载机制
    ///
    /// - Parameter type: 服务类型。例如：DemoService.self。
    /// - Returns: 与传入类型对应的服务实例。
    ///
    public func startService<ServiceType>(_ type:ServiceType.Type) -> ServiceType where ServiceType: Service {
        
        lock.lock()
        defer { lock.unlock() }
        
        let typeKey = String(describing: type)
        if let service = services[typeKey] {
            guard let service = service as? ServiceType else {
                fatalError()
            }
            return service
        } else {
            let service = type.init(self)
            services[typeKey] = service
            return service
        }
    }
    
    /// 当不再需要服务时停止它
    ///
    /// 有时，我们不需要在整个 VideoPlayerContainer 实例的生命周期内保持服务运行。
    /// 例如，我们有一个 Widget 使用了一个执行**计算密集型任务**或具有**内存缓存**的服务。
    /// 因此，当不再需要这个 widget 时，你应该调用它来释放资源。
    ///
    /// 技术实现：通过从服务字典中移除服务实例来实现资源释放
    ///
    @discardableResult public func stopService<ServiceType>(_ type:ServiceType.Type) -> Bool {
        
        lock.lock()
        defer { lock.unlock() }
        
        let typeKey = String(describing: type)
        if let _ = services[typeKey] {
            services[typeKey] = nil
            return true
        } else {
            return false
        }
    }
    
    /// ``startService(_:)`` 的简单替代方式。
    /// 技术实现：通过下标语法提供更简洁的服务访问方式
    public subscript<ServiceType>(_ type:ServiceType.Type) -> ServiceType where ServiceType: Service {
        startService(type)
    }
    
    private var dependencies = DependencyValues()
    
    /// 获取 ``Service`` 的外部依赖。
    ///
    /// 你可以使用 ``Dependency`` 属性包装器引入外部依赖。
    /// 通过这种方式，你可以轻松更改 Dependency 的实现来模拟外部依赖的返回值
    ///
    /// 技术实现：通过 KeyPath 实现类型安全的依赖访问
    ///
    /// - Parameter keyPath: 外部依赖的工厂位置。参见 ``DependencyValues``。
    ///
    public func dependency<Value>(_ keyPath: KeyPath<DependencyValues, Value>) -> Value {
        dependencies.dependency(keyPath)
    }
    
    /// 替换依赖的实现以模拟外部依赖的返回值。
    ///
    /// 技术实现：通过闭包注入实现依赖的动态替换，便于测试
    ///
    /// - Parameter keyPath: 外部依赖的工厂位置。参见 ``DependencyValues``。
    /// - Parameter factory: 你想要覆盖原始工厂的新工厂。
    ///
    public func withDependency<Value>(_ keyPath: KeyPath<DependencyValues, Value>, factory: ()->Value) {
        dependencies.withDependency(keyPath, factory: factory)
    }
}
