//
//  Test.swift
//  CloudShield
//
//  Created by Tan Elijah on 2023/7/13.
//

import Foundation

@objc public protocol CloudShieldDelegate: AnyObject {
    @objc func statusDidChanged(status: CloudShield.Status)
}

/// for XCTest DO NOT call function in this protocol !!!
protocol XCTestTracker {
    func testDomainSpeedTest(fullPathUrl: URL,
                         onSuccess: @escaping (_ model: SpeedTestResponse) -> Void,
                         onFailure: @escaping () -> Void)
    
    func testGetSpeedTestPath(domain: URL) -> URL
    
    func testGetDomainListFromGitHub(onSuccess: @escaping (_ urlList: Array<URL>) -> Void,
                                     onFailure: (() -> Void)?)
    func testGetDomainListFromBackupSite(onSuccess: @escaping (_ urlList: Array<URL>) -> Void,
                                     onFailure: (() -> Void)?)
}

@objc public class CloudShield: NSObject {
    @objc public static let shared = CloudShield()
    
    @objc public var delegate: CloudShieldDelegate?
    
    /// 記錄整個狀態進度
    @objc public private(set) var currentStatus: Status = .padding {
        didSet {
            handelStatusChange()
        }
    }
    
    @objc public private(set) var isUsingCloudShield = false
    
    @objc public private(set) var latestSuccessDomain: URL?
    
    private var localServiceUrl: URL?
    
    private var config: CloudShield.Config!
    
    /// 本地緩存的網址清單
    private var cacheDomainList: Array<URL>? {
        get {
            let domainListString = UserDefaults.standard.array(forKey: "\(Self.self).cacheDomainList") as? [String]
            let domainList = domainListString?.compactMap { URL(string: $0) }
            return domainList ?? config.domainArray.compactMap { URL(string: $0) }
        }
        set {
            guard let newValue else {
                UserDefaults.standard.removeObject(forKey: "\(Self.self).cacheDomainList")
                return
            }
            let domainListString = newValue.map { $0.absoluteString }
            UserDefaults.standard.set(domainListString, forKey: "\(Self.self).cacheDomainList")
        }
    }
    
    /// 第一個 response 回傳後, 移除此指標來放棄其他 response
    private var speedTestPointer: SpeedTestPointer?
    
    /// 紀錄速度測試的進度
    private var currentSpeedTestStatus = CurrentSpeedTestStatus(domainListSourceCount: 0)
    
    private override init() {}
    
    /// 初始化 cloud shield
    @objc public func startCloudShield(config: CloudShield.Config) {
        self.config = config
        currentStatus = .initializing
    }
    
    /// 取得 cloud shield 本地 url
    @objc public func getShieldUrl(withPath path: String? = nil) -> URL? {
        guard let path, var localServiceUrl else {
            return localServiceUrl
        }
        localServiceUrl = localServiceUrl.appendingPathComponent(path)
        return localServiceUrl
    }
    
    /// 開始競速測試
    @objc public func startSpeedTest() {
        currentStatus = .startDomainSpeedTest
    }
    
    /// 重启Kiwi本地代理服务器
    @objc public func restartAllServer() {
        KiwiBridge.restartAllServer()
    }
}

/// 處理 status
private extension CloudShield {
    func handelStatusChange() {
        delegate?.statusDidChanged(status: currentStatus)
        switch currentStatus {
        case .initializing:
            initKiwi()
        case .startLocalService:
            startLocalService()
        case .startDomainSpeedTest:
            handleSpeedTest()
        default:
            break
        }
    }
    
    /// 初始化 kiwi
    func initKiwi() {
        currentStatus = .initializing
        let kiwiInitResult = KiwiBridge.`init`(config.appKey)
        currentStatus = kiwiInitResult == 0 ? .initialized : .initializeFailure
        currentStatus = .startLocalService
    }
    
    /// 啟動本地代理 server
    func startLocalService() {
        guard currentStatus == .startLocalService else { return }
        let ipBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: 128)
        let portBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: 16)
        let result = KiwiBridge.server(toLocal: config.backupSiteCode, ipBuffer, 128, portBuffer, 16)
        
        guard result == 0 else {
            currentStatus = .localServiceFailure
            return
        }
        var components = URLComponents()
        components.scheme = "http"
        components.host = String(cString: ipBuffer)
        components.port = Int(String(cString: portBuffer))
        localServiceUrl = components.url
        currentStatus = localServiceUrl != nil ? .localServiceStarted : .localServiceFailure
    }
    
    func handleSpeedTest() {
        speedTestPointer = SpeedTestPointer()
        currentSpeedTestStatus = CurrentSpeedTestStatus(domainListSourceCount: 3)
        func receivedResponseAndUpdateStatus() {
            currentSpeedTestStatus.receivedDomainListSourceResponse()
            updateSpeedTestingStatus()
        }
        
        // 本地緩存
        if let cacheDomainList {
            updateSpeedTestingStatus()
            domainListSpeedTest(domainList: cacheDomainList)
        }
        
        // gitHub
        getDomainListFromGitHub(onSuccess: { domainList in
            self.domainListSpeedTest(domainList: domainList)
            receivedResponseAndUpdateStatus()
        }, onFailure: {
            receivedResponseAndUpdateStatus()
        })
        
        // 備用站點
        getDomainListFromBackupSite(onSuccess: { domainList in
            self.domainListSpeedTest(domainList: domainList)
            receivedResponseAndUpdateStatus()
        }, onFailure: {
            receivedResponseAndUpdateStatus()
        })
        
        // Kiwi shield 站點
        getDomainListFromCloudShield(onSuccess: { domainList in
            self.domainListSpeedTest(domainList: domainList)
            receivedResponseAndUpdateStatus()
        }, onFailure: {
            receivedResponseAndUpdateStatus()
        })
    }
    
    func updateSpeedTestingStatus(url: URL? = nil,
                                  isSpeedTestSuccess: Bool = false) {
        // 競速成功
        guard !isSpeedTestSuccess else {
            currentStatus = .domainSpeedTestSuccess
            return
        }
        
        if let url {
            currentSpeedTestStatus.addOrUpdateSpeedTestUrlStatus(url: url, result: isSpeedTestSuccess)
        }
        
        if currentSpeedTestStatus.isReceivedAllDomainListSource(),
           currentSpeedTestStatus.isAllSpeedTestFailure() {
            currentStatus = .domainSpeedTestFailure
        } else if currentSpeedTestStatus.isReceivedAllDomainListSource() {
            currentStatus = .domainSpeedTesting
        }
    }
}

private extension CloudShield {
    /// 競速域名路徑
    func getSpeedTestPath(domain: URL) -> URL {
        var domain = domain
        domain = domain.appendingPathComponent(config.domainSpeedTestPath)
        return domain
    }
    
    /// GET 請求, 加入 url 的參數
    func addQueryString(parameters: Dictionary<String, String>, url: URL) -> URL? {
        guard var component = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        let queryItems: Array<URLQueryItem> = parameters.map {
            URLQueryItem(name: $0, value: $1)
        }
        component.queryItems = queryItems
        return component.url
    }
    
    /// 速度測試用的請求參數
    var domainTestParameter: Dictionary<String, String>? {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return nil
        }
        return ["pkg_name": bundleIdentifier]
    }
    
    /// 域名測試
    func domainSpeedTest(fullPathUrl: URL,
                         onSuccess: @escaping (_ model: SpeedTestResponse) -> Void,
                         onFailure: @escaping () -> Void) {
        guard let domainTestParameter else { onFailure(); return }
        guard let fullPathUrl = addQueryString(parameters: domainTestParameter, url: fullPathUrl) else {
            onFailure(); return
        }
        let request = URLRequest(url: fullPathUrl)
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data else {
                DispatchQueue.main.async { onFailure() }
                return
            }
            if let model = try? JSONDecoder().decode(SpeedTestResponse.self, from: data),
               model.code == 200 {
                DispatchQueue.main.async { onSuccess(model) }
            } else {
                DispatchQueue.main.async { onFailure() }
            }
        }.resume()
    }
    
    /// 從 GitHub 取得域名
    func getDomainListFromGitHub(onSuccess: @escaping (_ urlList: Array<URL>) -> Void,
                                onFailure: (() -> Void)? = nil) {
        guard var url = URL(string: config.gitHubDomainListUrl) else {
            return
        }
        url = url.appendingPathComponent(config.gitHubDomainListPath)
        DispatchQueue(label: "gitHub").async {
            guard let data = try? Data(contentsOf: url) else {
                DispatchQueue.main.async { onFailure?() }
                return
            }
            guard let urlStringList = try? JSONDecoder().decode(Array<String>.self, from: data) else {
                DispatchQueue.main.async { onFailure?() }
                return
            }
            DispatchQueue.main.async { onSuccess(urlStringList.compactMap { URL(string: $0) }) }
        }
    }
    
    /// 從備用站取得域名
    func getDomainListFromBackupSite(onSuccess: @escaping (_ urlList: Array<URL>) -> Void,
                                     onFailure: (() -> Void)? = nil) {
        guard let url = URL(string: config.backupDomainListUrl) else {
            onFailure?()
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let parameter: Dictionary<String, String> = ["site": config.backupSiteCode]
        guard let data = try? JSONEncoder().encode(parameter) else {
            onFailure?()
            return
        }
        request.httpBody = data
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        session.dataTask(with: request, completionHandler: { data, response, error in
            // move callback to main threading
            func mainThreadAsyncOnFailure() {
                DispatchQueue.main.async { onFailure?() }
            }
            guard let data else { mainThreadAsyncOnFailure(); return }
            guard let urlStringList = try? JSONDecoder().decode(Array<String>.self, from: data) else {
                mainThreadAsyncOnFailure(); return
            }
            DispatchQueue.main.async { onSuccess(urlStringList.compactMap { URL(string: $0) }) }
        }).resume()
    }
    
    /// 從 CloudShield 取得域名
    /// CloudShieldUrl 本身也可以提供服務, 所以如果打通, 會先登記一次 latestSuccessDomain
    /// 再開始速度測試
    func getDomainListFromCloudShield(onSuccess: @escaping (_ urlList: Array<URL>) -> Void,
                                      onFailure: (() -> Void)? = nil) {
        guard let cloudShieldUrl = getShieldUrl() else {
            onFailure?()
            return
        }
        let fullpathUrl = getSpeedTestPath(domain: cloudShieldUrl)
        domainSpeedTest(
            fullPathUrl: fullpathUrl,
            onSuccess: { response in
                self.latestSuccessDomain = cloudShieldUrl
                onSuccess(response.data.siteConfig.appDomains.compactMap { URL(string: $0) })
            },
            onFailure: {
                onFailure?()
            }
        )
    }
    
    func domainListSpeedTest(domainList: [URL]) {
        let currentSpeedTestUrls = currentSpeedTestStatus.currentTestUrlList()
        let domainList = domainList.filter { !currentSpeedTestUrls.contains($0) }
        domainList.forEach { currentSpeedTestStatus.addOrUpdateSpeedTestUrlStatus(url: $0) }
        let queue = DispatchQueue(label: "domainListSpeedTest", attributes: .concurrent)
        
        for url in domainList {
            let fullPathUrl = getSpeedTestPath(domain: url)
            queue.async {
                self.domainSpeedTest(
                    fullPathUrl: fullPathUrl,
                    onSuccess: { [weak speedTestPointer = self.speedTestPointer] response in
                        guard let _ = speedTestPointer else { return }
                        self.speedTestPointer = nil
                        self.latestSuccessDomain = url
                        self.isUsingCloudShield = response.data.siteConfig.apiLine == .gameDun
                        
                        let appDomains = response.data.siteConfig.appDomains.compactMap { URL(string: $0) }
                        if appDomains.count > 0 {
                            self.cacheDomainList = appDomains
                        }
                        self.updateSpeedTestingStatus(url: url, isSpeedTestSuccess: true)
                    }, onFailure: { [weak speedTestPointer = self.speedTestPointer] in
                        // 檢查是否全部測試都失敗
                        guard let _ = speedTestPointer else { return }
                        self.updateSpeedTestingStatus(url: url, isSpeedTestSuccess: false)
                    }
                )
            }
        }
    }
}

// MARK: - for XCTest
extension CloudShield: XCTestTracker {
    func testDomainSpeedTest(fullPathUrl: URL,
                             onSuccess: @escaping (_ model: SpeedTestResponse) -> Void,
                             onFailure: @escaping () -> Void) {
        domainSpeedTest(fullPathUrl: fullPathUrl, onSuccess: onSuccess, onFailure: onFailure)
    }
    
    func testGetSpeedTestPath(domain: URL) -> URL {
        return getSpeedTestPath(domain: domain)
    }
    
    func testGetDomainListFromGitHub(onSuccess: @escaping (_ urlList: Array<URL>) -> Void,
                                     onFailure: (() -> Void)?) {
        getDomainListFromGitHub(onSuccess: onSuccess, onFailure: onFailure)
    }
    
    func testGetDomainListFromBackupSite(onSuccess: @escaping (_ urlList: Array<URL>) -> Void,
                                     onFailure: (() -> Void)?) {
        getDomainListFromBackupSite(onSuccess: onSuccess, onFailure: onFailure)
    }
}

// MARK: - call back 控制指標
class SpeedTestPointer {}

class CurrentSpeedTestStatus {
    private var domainListSourceCount: Int
    
    /// url : 測速完成結果是否成功
    /// nil 表示正在測速
    private var speedTestUrlStatus: Dictionary<URL, Bool?> = [:]
    
    init(domainListSourceCount: Int) {
        self.domainListSourceCount = domainListSourceCount
    }
    
    /// 接收到域名來源結果 (失敗也算一個結果)
    func receivedDomainListSourceResponse() {
        domainListSourceCount -= 1
    }
    
    /// 是否所有域名來源都已取得 response
    func isReceivedAllDomainListSource() -> Bool {
        /// 例如從 GitHub 取得域名, 這樣算是一個來源
        /// 一個來源對應一個結果
        /// 可能是 receivedDomainListSourceResponse 過度呼叫
        /// 或是一開始 domainListSourceCount 就設錯數量
        assert(domainListSourceCount >= 0, "網址請求來源數量不吻合")
        return domainListSourceCount <= 0
    }
    
    func currentTestUrlList() -> [URL] {
        return Array(speedTestUrlStatus.keys)
    }
    
    func addOrUpdateSpeedTestUrlStatus(url: URL, result: Bool? = nil) {
        speedTestUrlStatus[url] = result
    }
    
    func isAllSpeedTestFailure() -> Bool {
        let resultSet: Set<Bool?> = Set(speedTestUrlStatus.values)
        return resultSet == [false]
    }
}
