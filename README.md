Http Expires
--
* 使用 NSCache 緩存 api response 並加入過期機制
* [UrlCacheManager.swift](https://github.com/a110482/Resume/blob/main/UrlCacheManager.swift)

Domain test SDK
--
* 同時對三種來源網站做速度測試 (第三方服務, 自有網站, github) <br>
* 使用 test drive development 方法開發<br>
* [CloudShield.swift](https://github.com/a110482/Resume/blob/main/CloudShield.swift)

Http Header Storge
--
* 使用 Moya Plugin 和 httpHeaderStorge 來實現 Http Header 的資料欄位緩存
* [HeaderPlugin.swift](https://github.com/a110482/Resume/blob/main/HeaderPlugin.swift)

Aoto Update Manage
--
* api 自動重打: 因應 websocket 維修期間, 設計一套 AotoUpdateManage 配合網路部件設計, 只要向 manage 註冊 apiID 在網路層的決策階段, 就會通知 manage 在數秒後重新發送 api 以更新資料 <br>
* [AutoUpdateManager.swift](https://github.com/a110482/Resume/blob/main/AutoUpdateManager.swift)

UI Interface Changable
--
* 透過設計一個 protocol 並依附在 coordinator 之下構成一個繼承練, 達成整個模組可以熱切換 skin <br>
* [UIInterfaceChangable.swift](https://github.com/a110482/Resume/blob/main/UrlCacheManager.swift)