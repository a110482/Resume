//
//  AutoUpdataManage.swift
//  OB_API
//
//  Created by 譚培成 on 2021/11/6.
//

import Foundation

/// 管理 api 每四秒自動重打
/// 邏輯： 先在 api init 時 向 manager 註冊，表示受監管，然後透過 OBRequestBuilder:: send(req: ) 通知 manager 有api 即將送出
/// 就開始計時，然後等待 AutoupdateDecision 通知 api 已經有回應．這時候再決定何時要發送下次更新
public class AutoUpdateManager {
    #if DEBUG
    private let autoUpdateDuration: TimeInterval = 4
    #else
    private let autoUpdateDuration: TimeInterval = 4
    #endif
    public static let shared = AutoUpdateManager()
    
    private init() {
        timer = Timer.scheduledTimer(withTimeInterval: autoUpdateDuration, repeats: true, block: { [weak self] (_) in
            guard let self = self else { return }
            self.sendPool()
        })
    }
    
    private var supervisionRequests: Array<AutoUpdataManagerApiRegister> = []
    private var taskPool: Array<AutoUpdateTask> = []
    /// 因為不同支 api 資料上的時間戳會有同步問題, 所以時間計算就是每四秒集體發送所有 api , 而不是分開計時
    private var timer: Timer!
    
    /// 註冊 api 表示此 api 是受到監管的
    public func registerAPI(apiID: UUID, registrants: AnyObject) {
        let reg = AutoUpdataManagerApiRegister(apiID: apiID, registrants: registrants)
        supervisionRequests.append(reg)
    }
    
    /// 取消註冊 api
    public func unRegisterAPI(apiID: UUID) {
        supervisionRequests.removeAll(where: { $0.apiID == apiID })
    }
    
    /// 某隻 api 即將送出
    func willSend<Req: OBAPIRequest>(req: Req) {
        let apiID = req.apiID
        guard let index = supervisionRequests.firstIndex(where: { $0.apiID == apiID }) else {
            return
        }
        supervisionRequests[index].timeStamp = Date().timeIntervalSince1970
    }
    
    /// 收到 api 回應訊號
    func reciveResponse<Req: OBAPIRequest>(req: Req, autoUpdate: @escaping () -> Void) {
        checkRegisterValid()
        let apiID = req.apiID
        guard let _ = self.isApiInSupervision(apiID: apiID) else { return }
        taskPool.append(.init(apiID: apiID, autoUpdate: autoUpdate))
    }
}

private extension AutoUpdateManager {
    /// 移除監聽者已消除的 api
    func checkRegisterValid() {
        supervisionRequests.removeAll(where: { $0.registrants == nil })
    }
    
    /// 檢查 api 有沒有在監管中
    func isApiInSupervision(apiID: UUID) -> Array<AutoUpdataManagerApiRegister>.Index? {
        guard let index = self.supervisionRequests.firstIndex(where: { $0.apiID == apiID }) else {
            return nil
        }
        return index
    }
    
    func sendPool() {
        let copyTasks = taskPool
        taskPool = []
        for task in copyTasks {
            if let _ = self.isApiInSupervision(apiID: task.apiID) {
                task.autoUpdate()
            }
        }
    }
}

/// 紀錄api被監管狀態
private struct AutoUpdataManagerApiRegister {
    let apiID: UUID
    /// registrants 是在為了檢測監聽者是否還存在，如果消失的話就不再繼續重打此api
    weak var registrants: AnyObject?
    /// 上次發送的時間戳記
    var timeStamp = Date().timeIntervalSince1970
    
    public init(apiID: UUID, registrants: AnyObject?) {
        self.apiID = apiID
        self.registrants = registrants
    }
}

private struct AutoUpdateTask {
    let apiID: UUID
    let autoUpdate: () -> Void
}
