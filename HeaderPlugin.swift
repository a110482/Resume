//
//  HeaderPlugin.swift
//  
//
//  Created by 譚培成 on 2021/7/20.
//

import Foundation
import Moya


public struct HeaderPlugin: PluginType {
    var headerKeys: Array<String>
    init(headerKeys: Array<String>, storage: HeaderPluginStorage = HeaderPluginStorage.default) {
        self.headerKeys = headerKeys
        self.storage = storage
    }
    
    public func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        var request = request
        guard let host = request.url?.host else { return request }
        for key in headerKeys {
            if let value = storage.getHeader(for: host, key: key) {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        return request
    }

    public func didReceive(_ result: Result<Moya.Response, MoyaError>, target: TargetType) {
        guard case let .success(res) = result else { return }
        guard let host = res.request?.url?.host else { return }
        guard let headers = res.response?.allHeaderFields else { return }
        let stringHeaders = headers.compactMapValues( { $0 as? String} )
        
        for header in stringHeaders {
            if let key = header.key as? String, headerKeys.contains(key) {
                storage.setHeader(for: host, key: key, value: header.value)
            }
        }
        
    }
    
    private var storage: HeaderPluginStorage
}

// 如果有不同網域要共用 header 需求
// 可以加入 group 概念
public class HeaderPluginStorage {
    static let `default` = HeaderPluginStorage()
    
    public init() {}
    
    public func setHeader(for host: String, key: String, value: String) {
        if let index = headerStorages.firstIndex( where: { $0.host == host } ) {
            var newStorage = headerStorages[index]
            newStorage.headerKeyValue[key] = value
            headerStorages[index] = newStorage
        } else {
            let newStorage = HeaderStorage(host: host, headerKeyValue: [key: value])
            headerStorages.append(newStorage)
        }
    }
    
    public func getHeader(for host: String, key: String) -> String? {
        if let index = headerStorages.firstIndex( where: { $0.host == host } ) {
            return headerStorages[index].headerKeyValue[key]
        }
        return nil
    }
    
    private struct HeaderStorage: Hashable {
        let host: String
        var headerKeyValue: Dictionary<String, String> = [:]
    }
     
    private var headerStorages: Array<HeaderStorage> = []
}
