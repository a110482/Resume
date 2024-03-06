//
//  UIInterfaceChangable.swift
//  JX_SBK_UI_MODULE
//
//  Created by 譚培成 on 2021/10/14.
//

import UIKit

/// 更改專業版介面
public class UIInterfaceManager {
    public static let shared = UIInterfaceManager()
    var interfaceMode: UIInterfaceMode = .lite {
        didSet {
            rootObject?.applyMode(interfaceMode)
        }
    }
    weak var rootObject: UIInterfaceChangAble?
    func reFlash() {
        rootObject?.applyMode(interfaceMode)
    }
    private init() {}
}

public enum UIInterfaceMode {
    case lite, professional
}

protocol UIInterfaceChangAble: AnyObject {
    /// 用來檢查繼承練
//    var parent: UIInterfaceChangAble? { get set }
    /// 如果實做了此函數，務必確認有呼叫 applyModeToSubObjects
    func applyMode(_ mode: UIInterfaceMode)
    func applyModeToSubObjects(_ mode: UIInterfaceMode)
    var changeAbleSubObjects: Array<UIInterfaceChangable> { get }
}

extension UIInterfaceChangAble {
    func applyMode(_ mode: UIInterfaceMode) {
        applyModeToSubObjects(mode)
    }
    
    func applyModeToSubObjects(_ mode: UIInterfaceMode) {
        changAbleSubObjects.forEach { $0.applyMode(mode) }
    }
    
    var changAbleSubObjects: Array<UIInterfaceChangAble> {[]}
}

/// 先強制使用 light 版本
extension UIInterfaceChangAble where Self: UIViewController {
    func customUISetting() {
        overrideUserInterfaceStyle = .light
    }
    
    func applyMode(_ mode: UIInterfaceMode) {
        customUISetting()
        applyModeToSubObjects(mode)
    }
}

extension UIViewController: UIInterfaceChangAble {}
