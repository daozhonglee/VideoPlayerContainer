//
//  Dependency.swift
//  VideoPlayerContainer
//
//  Created by shayanbo on 2023/8/9.
//

import Foundation

/// 一个属性包装器，用于在你的 ``Service`` 中引入外部依赖。
///
/// 我们建议开发者使用这个属性包装器来使用外部功能。通过这种方式，在单元测试中，你可以通过调用 ``Context/withDependency(_:factory:)`` 轻松替换其实现。
///
/// 技术实现：使用属性包装器和泛型实现依赖注入，通过 KeyPath 实现类型安全的依赖访问
///
/// 例如：假设我们有一个从远程服务器获取数字的 http 客户端，并编写一个 Service，提供一个 API，该 API 仅调用 http 客户端来获取数字并作为 API 的结果返回。
/// ```swift
/// class TargetService: Service {
///
///     @Dependency(\.numberClient) var numberClient
///
///     @Published var data: Int?
///     @Published var error: Error?
///
///     func fetchData() async throws -> Int {
///         do {
///             self.data = try await numberClient.fetch()
///         } catch {
///             self.error = error
///         }
///     }
/// }
///
/// struct NumberClient {
///     var fetch: () async throws -> Int
/// }
///
/// extension DependencyValues {
///
///     var numberClient: NumberClient {
///         NumberClient {
///             let (data, _) = try await URLSession.shared.data(from: URL(string:"http://numbersapi.com/random/trivia")!)
///             let str = String(data: data, encoding: .utf8)
///             return Int(str?.components(separatedBy: " ").first ?? "") ?? 0
///         }
///     }
/// }
/// ```
///
/// 在这里，我们使用 @Dependency 来引入外部依赖，实现是 DependencyValues 的扩展。这个 DependencyValues 的唯一实例保存在 ``Context`` 中。因此，所有依赖项的生命周期都与 ``Context`` 保持一致。
/// 除了协议之外，我们还可以使用带有闭包属性的结构体/类来实现 IoC，就像上面的 NumberClient 结构体一样。
///
/// 当我们编写**单元测试**时，我们可以通过使用 ``Context/withDependency(_:factory:)`` 轻松替换外部依赖的实现
/// ```swift
/// func testFetchSuccess() async throws {
///
///     let context = Context()
///     let target = context[TargetService.self]
///
///     context.withDependency(\.numberClient) {
///         NumberClient { 10 }
///     }
///
///     try await target.fetchData()
///
///     XCTAssertNotNil(target.data)
///     XCTAssertNil(target.error)
///     XCTAssertEqual(target.data!, 10)
/// }
/// ```
///
/// - 重要提示: 通过在 ``Service`` 中定义的 @``Dependency`` 和 @``ViewState``，我们可以轻松了解这个 Service 依赖于多少个外部依赖，维护了多少个状态。
///
@propertyWrapper
public struct Dependency<Value> {
    
    public var wrappedValue: Value {
        fatalError()
    }
    
    private let keyPath: KeyPath<DependencyValues, Value>
    
    public init(_ keyPath: KeyPath<DependencyValues, Value>) {
        self.keyPath = keyPath
    }
    
    public static subscript<OuterSelf: Service>(_enclosingInstance observed: OuterSelf, wrapped wrappedKeyPath: KeyPath<OuterSelf, Value>, storage storageKeyPath: ReferenceWritableKeyPath<OuterSelf, Self>) -> Value? {
        
        let keyPath = observed[keyPath: storageKeyPath].keyPath
        return observed.context?.dependency(keyPath)
    }
}

/// 保存所有依赖项实例。
///
/// 所有依赖项都应该是它的只读计算属性扩展。
/// 它的唯一实例保存在 ``Context`` 中。参见 ``Dependency``。
///
/// 技术实现：使用字典存储依赖实例，通过递归锁确保线程安全，实现依赖的单例模式和懒加载机制
///
public struct DependencyValues {
    
    private var dependencies = [String: Any]()
    
    private let lock = NSRecursiveLock()
    
    mutating func dependency<Value>(_ keyPath: KeyPath<DependencyValues, Value>) -> Value {
        
        lock.lock()
        defer { lock.unlock()}
        
        let typeKey = String(describing: Value.self)
        
        if dependencies[typeKey] == nil {
            dependencies[typeKey] = self[keyPath: keyPath]
        }
        
        guard let dep = dependencies[typeKey] as? Value else {
            fatalError()
        }
        return dep
    }
    
    mutating func withDependency<Value>(_ keyPath: KeyPath<DependencyValues, Value>, factory: ()->Value) {
        
        lock.lock()
        defer { lock.unlock()}
        
        let typeKey = String(describing: Value.self)
        dependencies[typeKey] = factory()
    }
}
