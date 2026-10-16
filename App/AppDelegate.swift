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

    private var splash: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        // superview 用红色背景，状态栏区域颜色跟 uni-app 导航栏一致
        view.backgroundColor = UIColor(red: 0.91, green: 0.23, blue: 0.20, alpha: 1.0)

        let cfg = WKWebViewConfiguration()
        cfg.preferences.javaScriptEnabled = true

        web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = self
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.isOpaque = false
        web.backgroundColor = .white
        web.alpha = 0  // 加载完成前先隐藏，避免白屏闪烁
        view.addSubview(web)

        // 启动屏（白底 + 加载提示），避免冷启动白屏
        let sp = UIView(frame: view.bounds)
        sp.backgroundColor = .white
        sp.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let label = UILabel()
        label.text = "加载中…"
        label.textColor = UIColor(white: 0.4, alpha: 1.0)
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        sp.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: sp.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: sp.centerYAnchor),
        ])
        view.addSubview(sp)
        splash = sp

        loadEntry()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // WebView 物理上避开 safe-area.top：红色 fixed 导航栏自然出现在状态栏下方
        let top = view.safeAreaInsets.top
        web.frame = CGRect(x: 0, y: top, width: view.bounds.width, height: view.bounds.height - top)
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

    // 页面加载完成：显示 WebView，隐藏启动屏
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        UIView.animate(withDuration: 0.2) {
            webView.alpha = 1
            self.splash?.alpha = 0
        } completion: { _ in
            self.splash?.removeFromSuperview()
            self.splash = nil
        }
    }
}
