import UIkit

struct ThemeSetting {
    /// 寫入 static 變數，避免重複讀取 plist
    static private let themeCode = "green" //CustomConfig.themeCode()
    static private(set) var currentThemeStyle: ThemeStyle = .dark

    static var theme: any ThemeProtocol {
        switch themeCode {
        case "blue":
            return themeAssetsBlue.theme
        case "green":
            return themeAssetsGreen.theme
        default:
            return themeAssetsGreen.theme
        }
    }
    
    static let themeAssetsGreen = ThemeAssets(themeLight: ThemeLightGreen(),
                                                         themeDark: ThemeDarkGreen())
    static let themeAssetsBlue = ThemeAssets(themeLight: ThemeLightBlue(),
                                                       themeDark: ThemeDarkBlue())
}
enum ThemeStyle {
    case dark
    case light
}

struct ThemeAssets {
    var theme: ThemeProtocol {
        switch ThemeSetting.currentThemeStyle {
        case .dark:
            return themeDark
        case .light:
            return themeLight
        }
    }
    
    init(themeLight: ThemeProtocol, themeDark: ThemeProtocol) {
        self.themeLight = themeLight
        self.themeDark = themeDark
    }
    
    let themeLight: ThemeProtocol
    let themeDark: ThemeProtocol
}

protocol ThemeProtocol {
    var baseColor: UIColor { get }
    var themeColor: UIColor { get }
}

// 綠色共用色
protocol ThemeBaseGreen {}

extension ThemeBaseGreen {
    var baseColor: UIColor { .green }
}

// 綠色日版
protocol ThemeBaseLightGreen: ThemeBaseGreen {
    var themeColor: UIColor { get }
}

extension ThemeBaseLightGreen {
    var themeColor: UIColor { .white }
}

class ThemeLightGreen: ThemeBaseLightGreen, ThemeProtocol {}

// 綠色夜版
protocol ThemeBaseDarkGreen: ThemeBaseGreen {
    var themeColor: UIColor { get }
}

extension ThemeBaseDarkGreen {
    var themeColor: UIColor { .black }
}

class ThemeDarkGreen: ThemeBaseDarkGreen, ThemeProtocol {}

// 藍色共用版
protocol ThemeBaseBlue: ThemeBaseGreen {}

// 藍色日版
protocol ThemeBaseLightBlue: ThemeBaseLightGreen, ThemeBaseBlue {}

extension ThemeBaseLightBlue {
    var themeColor: UIColor { .lightGray }
}

class ThemeLightBlue: ThemeBaseLightBlue, ThemeProtocol {}

// 藍色夜版
protocol ThemeBaseDarkBlue: ThemeBaseDarkGreen, ThemeBaseBlue {}

extension ThemeBaseDarkBlue {}

class ThemeDarkBlue: ThemeBaseDarkBlue, ThemeProtocol {}

// demo
UIView().backgroundColor = ThemeSetting.theme.themeColor
