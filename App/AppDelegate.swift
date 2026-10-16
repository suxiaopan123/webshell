import UIKit
import WebKit

struct ShellCfg: Decodable { let url: String }

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = WebVC()
        w.makeKeyAndVisible()
        window = w
        return true
    }
}

class WebVC: UIViewController, WKNavigationDelegate {
    private var web: WKWebView!

    // 支付/拉起外部 App 用的 Universal Links 域名白名单
    private let payHosts = [
        "render.alipay.com", "client.alipay.com", "m.alipay.com", "ds.alipay.com",
        "cashier.alipay.com", "wappaygw.alipay.com",
        "wx.tenpay.com", "pay.weixin.qq.com", "payapp.weixin.qq.com",
        "unionpaysecure.com", "mobile.unionpay.com", "95516.com",
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        // superview 用红色背景，状态栏区域颜色跟 uni-app 导航栏一致
        view.backgroundColor = UIColor(red: 0.91, green: 0.23, blue: 0.20, alpha: 1.0)

        let cfg = WKWebViewConfiguration()
        cfg.preferences.javaScriptEnabled = true
        // 注入 CSS：保险起见，给常见导航栏 class 加 safe-area padding
        let css = """
        .uni-page-head, .uni-navbar, header, [class*="navbar"], [class*="nav-bar"] {
            padding-top: env(safe-area-inset-top) !important;
        }
        """
        let js = "var s=document.createElement('style');s.textContent=\(css.debugDescription);document.head.appendChild(s);"
        cfg.userContentController.addUserScript(
            WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        )

        web = WKWebView(frame: view.bounds, configuration: cfg)
        web.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // 自动避开 safe-area：红色导航栏自然出现在状态栏下方
        web.scrollView.contentInsetAdjustmentBehavior = .always
        // 禁用下拉橡皮筋，避免错位
        web.scrollView.bounces = false
        web.navigationDelegate = self
        web.isOpaque = false
        web.backgroundColor = .white
        view.addSubview(web)
        loadEntry()
    }

    private func loadEntry() {
        var urlStr = "https://example.com"
        if let p = Bundle.main.url(forResource: "config", withExtension: "json"),
           let data = try? Data(contentsOf: p),
           let cfg = try? JSONDecoder().decode(ShellCfg.self, from: data),
           !cfg.url.isEmpty {
            urlStr = cfg.url
        }
        if let u = URL(string: urlStr) {
            web.load(URLRequest(url: u))
        }
    }

    // 拦截自定义 scheme + 支付 Universal Links，跳外部 App
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow); return
        }
        let scheme = (url.scheme ?? "").lowercased()
        let host = (url.host ?? "").lowercased()

        // http/https 且命中支付域名 → 跳外部 App
        if (scheme == "https" || scheme == "http"),
           payHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }

        // http/https/about → WebView 内打开
        if scheme == "http" || scheme == "https" || scheme == "about" || scheme == "data" {
            decisionHandler(.allow)
            return
        }

        // 其他自定义 scheme（alipay://、weixin://、tel:、mailto: 等）→ 跳外部
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        decisionHandler(.cancel)
    }

    // target="_blank" 在当前 WebView 打开
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let target = navigationAction.targetFrame, target.isMainFrame {
            return nil
        }
        webView.load(navigationAction.request)
        return nil
    }
}
