
import Foundation
import AppKit

class ProxyConfigManager {
    static let kProxyConfigFolder = (NSHomeDirectory() as NSString).appendingPathComponent("/.config/clash")
    static let kVersion = "0.1.1"

    /// 检查 ProxyConfig 存不存在，版本是否正确，
    static func vaildHelper() -> Bool {
        let scriptPath = "\(Bundle.main.resourcePath!)/check_proxy_helper.sh"
        let appleScriptStr = "do shell script \"bash \\\"\(scriptPath)\\\" \(kProxyConfigFolder) \(kVersion) \" "
        let appleScript = NSAppleScript(source: appleScriptStr)
        var dict: NSDictionary?
        if let res = appleScript?.executeAndReturnError(&dict) {
            if (res.stringValue?.contains("success")) ?? false {
                return true
            }
        } else {
            Logger.log(msg: "\(String(describing: dict))",level: .error)
        }
        return false
        
    }

    /// 检查 clash 目录，Country.mmdb 文件，复制 ProxyConfig 文件到 clash 文件夹
    static func install() -> Bool {
        checkConfigDir()
        checkMMDB()
        
        let proxyHelperPath = Bundle.main.path(forResource: "ProxyConfig", ofType: nil)
        let targetPath = "\(kProxyConfigFolder)/ProxyConfig"
        
        /// 检查 ProxyConfig 存不存在，版本是否正确，如果不正确，执行下面操作
        if !vaildHelper() {
            /// 用户不允许则退出
            if (!showInstallHelperAlert()) {
                exit(0)
            }
            
            if (FileManager.default.fileExists(atPath: targetPath)) {
                try? FileManager.default.removeItem(atPath: targetPath)
            }
            /// 将 bundle 里的 ProxyConfig 复制到 ~/.config/clash 目录
            try? FileManager.default.copyItem(at: URL(fileURLWithPath: proxyHelperPath!), to: URL(fileURLWithPath: targetPath))
            
            /// 将 ProxyConfig 所有者改成 root:admin 并进行升权
            let scriptPath = "\(Bundle.main.resourcePath!)/install_proxy_helper.sh"
            let appleScriptStr = "do shell script \"bash \(scriptPath) \(kProxyConfigFolder) \" with administrator privileges"
            let appleScript = NSAppleScript(source: appleScriptStr)
                        
            var dict: NSDictionary?
            if let _ = appleScript?.executeAndReturnError(&dict) {
                return true
            } else {
                return false
            }
        }
        return true
    }
    
    /// 检查 系统 clash 目录是否已经存在，不存在则创建
    static func checkConfigDir() {
        var isDir : ObjCBool = true
        if !FileManager.default.fileExists(atPath: kProxyConfigFolder, isDirectory:&isDir) {
            try? FileManager.default.createDirectory(atPath: kProxyConfigFolder, withIntermediateDirectories: false, attributes: nil)
        }
    }
    
    
    /// 检查 clash 目录中 Country.mmdb 文件是否存在， 不存在则拷贝内置 Country.mmdb 到 clash目录
    static func checkMMDB() {
        let fileManage = FileManager.default
        let destMMDBPath = "\(kProxyConfigFolder)/Country.mmdb"
        if !fileManage.fileExists(atPath: destMMDBPath) {
            if let mmdbPath = Bundle.main.path(forResource: "Country", ofType: "mmdb") {
                try? fileManage.copyItem(at: URL(fileURLWithPath: mmdbPath), to: URL(fileURLWithPath: destMMDBPath))
            }
        }
    }
    
    
    /// 启用一个子进程运行 ProxyConfig
    ///
    /// - Parameters:
    ///   - port: http 端口
    ///   - socksPort: socks 端口
    /// - Returns: 正常退出返回 true
    static func setUpSystemProxy(port: Int?,socksPort: Int?) -> Bool {
        let task = Process()
        task.launchPath = "\(kProxyConfigFolder)/ProxyConfig"
        if let port = port,let socksPort = socksPort {
            task.arguments = [String(port),String(socksPort), "enable"]
        } else {
            task.arguments = ["0", "0", "disable"]
        }
        
        task.launch()
        
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            return false
        }
        return true
    }
    
    /// 提示是否安装 工具 到 ~/.config/clash, 如果用户允许 return true
    static func showInstallHelperAlert() -> Bool{
        let alert = NSAlert()
        alert.messageText = """
        ClashX needs to install a small tool to ~/.config/clash with administrator privileges to set system proxy quickly.
        
        Otherwise you need to type in the administrator password every time you change system proxy through ClashX.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Quit")
        return alert.runModal() == .alertFirstButtonReturn
    }

}
