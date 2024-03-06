//
//  EncryptedPlugin.swift
//
//
//  Created by Tan Elijah on 2023/3/24.
//

import Moya

struct EncryptedPlugin: PluginType {
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        guard let httpBody = request.httpBody else {
            return request
        }
        guard let jsonStringBody = dataToJsonString(data: httpBody) else {
            return request
        }
        let timeStamp = String(Int(Date().timeIntervalSince1970))
        let newBodyString = jsonStringBody + timeStamp
        guard let encryptedData: NSDictionary = Encrypted.encrypt(newBodyString) as? NSDictionary else {
            return request
        }
        guard let AESKey = encryptedData["AESKey"] as? String else {
            return request
        }
        guard let body = encryptedData["EncryptedBody"] as? String else {
            return request
        }
        var newHeaders = request.headers
        newHeaders.update(name: "request-id", value: AESKey)
        newHeaders.update(name: "timestamp", value: timeStamp)
        newHeaders.update(name: "encryptResponse", value: "1")
        let newEncryptedBody = ["encryptedBody": body]
        var newRequest = request
        newRequest.headers = newHeaders
        newRequest.httpBody = dictionaryToData(newEncryptedBody)
        return newRequest
    }
    
    func process(_ result: Result<Moya.Response, MoyaError>, target: TargetType) -> Result<Moya.Response, MoyaError> {
        switch result {
        case .success(let response):
            return handleSuccess(response: response)
        case .failure(let error):
            return handleFailure(error: error)
        }
    }
    
    private func handleSuccess(response: Response) -> Result<Moya.Response, MoyaError> {
        let url = response.request?.url?.absoluteString ?? ""
        let hint = url.replacingOccurrences(of: "/", with: "")
        let statusCode = response.statusCode
        let headers = response.response?.headers
        
        /// 響應失敗結果
        func returnFailure(code: String) -> Result<Moya.Response, MoyaError> {
            let customError = NSError(domain: hint + code, code: statusCode, userInfo: nil)
            return .failure(MoyaError.underlying(customError, response))
        }
        
        guard !response.data.isEmpty else {
            return returnFailure(code: "4")
        }
        
        guard let contentType = response.response?.headers["Content-Type"],
              contentType == "text/html; charset=UTF-8" else {
            // 不解碼, 直接返回處理
            return .success(response)
        }
        
        // 解碼流程
        let aesKey = headers?.value(for: "request-id") ?? headers?.value(for: "Request-Id")
        guard let aesKey = aesKey,
              let dataString = String(data: response.data, encoding: .utf8),
              let decrypt = Encrypted.decrypt(dataString, secretKey: aesKey)
        else {
            return returnFailure(code: "2")
        }
        guard let decryptData = decrypt.data(using: .utf8) else {
            return returnFailure(code: "3")
        }
        let newResponse = Response(
            statusCode: response.statusCode,
            data: decryptData,
            request: response.request,
            response: response.response
        )
        return .success(newResponse)
    }
    
    private func handleFailure(error: MoyaError) -> Result<Moya.Response, MoyaError> {
        let url = error.response?.request?.url?.absoluteString ?? ""
        let hint = url.replacingOccurrences(of: "/", with: "") + "1"
        let statusCode = error.response?.statusCode ?? 404
        let customError = NSError(domain: hint + "1", code: statusCode, userInfo: nil)
        return .failure(MoyaError.underlying(customError, error.response))
    }
    
    private func dataToJsonString(data: Data) -> String? {
        let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
        let jsonData = try? JSONSerialization.data(withJSONObject: json ?? "", options: .prettyPrinted)
        let jsonString = String(data: jsonData ?? Data(), encoding: .utf8)
        return jsonString
    }
    
    private func dictionaryToData(_ dic: [String: Any]) -> Data? {
        return try? JSONSerialization.data(withJSONObject: dic, options: [])
    }
}
