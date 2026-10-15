import UIKit
import WebKit

struct ShellCfg: Decodable { let url: String }

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

class WebVC: UIViewController {
    private var web: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        web = WKWebView(frame: view.bounds)
        web.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.configuration.preferences.javaScriptEnabled = true
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
}
