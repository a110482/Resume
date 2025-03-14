import UIKit
import RxSwift
import RxCocoa

/// 用來管理本地化設置的儲存庫
private class RXLocalizedStore {
    static let shared = RXLocalizedStore()

    /// 將新的本地化設置加入儲存庫
    func add(_ setting: RXLocalizedSetting) {
        removeDuplicate(setting)
        settings.append(setting)
        setting.active()
        setNeedPrune()
    }
    
    /// 儲存所有的本地化設置
    private var settings: [RXLocalizedSetting] = []
    private let needPrune = PublishRelay<Void>()
    /// 用於管理訂閱的 DisposeBag
    private let disposeBag = DisposeBag()
    
    private init() {
        /// 訂閱語言變更通知以進行刷新
        UserManager.shared.language.subscribe(with: self) { store, _ in
            store.refresh()
        }.disposed(by: disposeBag)
    }
}

private extension RXLocalizedStore {
    /// 刷新所有設置，使它們變為活動狀態
    func refresh() {
        settings.forEach { setting in
            setting.active()
        }
    }
    
    /// 設置需要清理無效的設定檔
    func setNeedPrune() {
        needPrune.accept(())
    }
    
    /// 請勿直接呼叫此函數
    func prune() {
        settings = settings.filter { $0.target != nil }
    }
    
    /// 移除重複的設置，根據 target 進行比較
    func removeDuplicate(_ setting: RXLocalizedSetting) {
        let target = setting.target
        settings.removeAll(where: { $0.target === target })
    }
}

/// 本地化設置類別
private class RXLocalizedSetting {
    /// 目標視圖
    weak var target: UIView?
    /// 激活設置的操作
    var active: () -> Void
    
    init(target: UIView, active: @escaping () -> Void) {
        self.target = target
        self.active = active
    }
}

/// 用於為指定視圖提供本地化支持的類別
class RxRXLocalized<T: UIView> {
    weak var target: T?
    var re: RxThemeExtension<T> {
        return RxThemeExtension(target!, rl: self)
    }
    
    init(_ target: T) {
        self.target = target
    }
    
    init(_ target: T, re: RxThemeExtension<T>) {
        self.target = target
        self.rePointer = re
    }
    
    /// 同時接收語言和顏色訊號
    private var rePointer: RxThemeExtension<T>?
}

/// 定義了 RxRXLocalizedProtocol 協議，用於將本地化設置與視圖關聯
protocol RxRXLocalizedProtocol {
    associatedtype T: UIView
    var rl: RxRXLocalized<T> { get }
}

/// 對於所有遵循 UIView 的類型，提供 rl 屬性以獲取本地化設置
extension RxRXLocalizedProtocol where Self: UIView {
    var rl: RxRXLocalized<Self> {
        return RxRXLocalized(self)
    }
}

/// 擴展 UIView 以遵循 RxRXLocalizedProtocol 協議
extension UIView: RxRXLocalizedProtocol {}

/// 定義本地化配置結構
struct RXLocalizedConfig {
    /// 本地化鍵/
    var key: String
    /// 註解
    var comment: String
    
    var font: (() -> UIFont)?
}


// MARK: - 其他ＵＩ元件請往下新增

// UILabel
extension RxRXLocalized where T: UILabel {
    var text: RXLocalizedConfig {
        get {
            assert(false)
            let defaultText = target?.text ?? ""
            return RXLocalizedConfig(key: defaultText, comment: "")
        }
        
        set {
            guard let target else { return }
            let setting = RXLocalizedSetting(target: target) { [weak target] in
                guard let target else { return }
                target.text = NSLocalizedString(newValue.key, comment: newValue.comment)
                guard let font = newValue.font else { return }
                target.font = font()
            }
            RXLocalizedStore.shared.add(setting)
        }
    }
    
    var textClosure: () -> String {
        get {{""}}
        set {
            guard let target else { return }
            let setting = RXLocalizedSetting(target: target) { [weak target] in
                guard let target else { return }
                target.text = newValue()
            }
            RXLocalizedStore.shared.add(setting)
        }
    }
    
    func setAttributedText(attributedText: @escaping () -> NSAttributedString?) {
        guard let target else { return }
        let setting = RXLocalizedSetting(target: target) { [weak target] in
            guard let target else { return }
            target.attributedText = attributedText()
        }
        RXLocalizedStore.shared.add(setting)
        
        if let rePointer {
            rePointer.setAttributedText(attributedText: attributedText)
        }
    }
}

// UIButton
extension RxRXLocalized where T: UIButton {
    var title: RXLocalizedConfig {
        get {
            assert(false)
            let defaultText = target?.titleLabel?.text ?? ""
            return RXLocalizedConfig(key: defaultText, comment: "")
        }
        
        set {
            guard let target else { return }
            let setting = RXLocalizedSetting(target: target) { [weak target] in
                guard let target else { return }
                let text = NSLocalizedString(newValue.key, comment: newValue.comment)
                target.setTitle(text, for: .normal)
                guard let font = newValue.font else { return }
                target.titleLabel?.font = font()
            }
            RXLocalizedStore.shared.add(setting)
        }
    }
    
    var titleClosure: () -> String {
        get {{""}}
        set {
            guard let target else { return }
            let setting = RXLocalizedSetting(target: target) { [weak target] in
                guard let target else { return }
                target.setTitle(newValue(), for: .normal)
            }
            RXLocalizedStore.shared.add(setting)
        }
    }
}
