//
//  UrlCacheManager.swift
//  
//
//  Created by Tan Elijah on 2023/3/16.
//

import Foundation

class UrlCacheManager {
    static let cache = NSCache<UrlParameterHashKey, UrlCacheDate>()
}

class UrlParameterHashKey: NSObject {
    private let url: String
    private let parameters: Dictionary<String, Any>?
    
    init(url: String, parameters: Dictionary<String, Any>? = nil) {
        self.url = url
        self.parameters = parameters
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UrlParameterHashKey else {
            return false
        }
        return hash == other.hash
    }
    
    override var hash: Int {
        let hashString = "url:\(url);\(parametersString())"
        return hashString.hash
    }
    
    private func parametersString() -> String {
        guard let parameters = parameters else { return "" }
        let dicArray = parameters.sorted(by: { $0.key > $1.key })
        return dicArray.reduce("", {
            $0 + "\($1.key):\($1.value);"
        })
    }
}

class UrlCacheDate {
    private let responseDate: Dictionary<String, Any>
    private let expiresDate: Date
    
    init?(expires: String?, responseDate: Dictionary<String, Any>?) {
        guard let expires = expires,
              let responseDate = responseDate else { return
             nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        guard let expiresDate = formatter.date(from: expires) else { return nil }
        self.expiresDate = expiresDate
        self.responseDate = responseDate
    }
    
    func getResponseDate() -> Dictionary<String, Any>? {
        guard Date() < expiresDate else {
            return nil
        }
        return responseDate
    }
}
