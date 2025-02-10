//
//  ViewSizeService.swift
//  VideoPlayer
//
//  Created by shayanbo on 2023/6/19.
//

import Foundation

/// 非 Widget 服务，用于维护 VideoPlayerContainer 的尺寸信息。
public class ViewSizeService : Service {
    
    private(set) var size = CGSize.zero
    
    /// VideoPlayerContainer 的宽度。
    public var width: Double {
        size.width
    }
    
    /// VideoPlayerContainer 的高度。
    public var height: Double {
        size.height
    }
    
    func updateViewSize(_ size: CGSize) {
        self.size = size
    }
}

public extension Context {
    
    /// context[ViewSizeService.self] 的简单替代方式
    var viewSize: ViewSizeService {
        self[ViewSizeService.self]
    }
}
