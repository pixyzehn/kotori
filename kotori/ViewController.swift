import Cocoa
import WebKit

class ViewController: NSViewController, WKNavigationDelegate, WKUIDelegate {
    var webView: WKWebView!

    deinit {
        webView.removeObserver(self, forKeyPath: "title", context: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let config = WKWebViewConfiguration()
        let scriptURL = Bundle.main.resourcePath! + "/kotori.js"
        var javascript = try! String(contentsOfFile: scriptURL)
        javascript += "changeTextAreaFont();"
        let script = WKUserScript(source: javascript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)

        webView = WKWebView(frame: self.view.bounds, configuration: config)
        webView.frame = self.view.frame
        webView.autoresizingMask = NSAutoresizingMaskOptions(arrayLiteral: .viewWidthSizable, .viewHeightSizable)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.addObserver(self, forKeyPath: "title", options: NSKeyValueObservingOptions.new, context: nil)

        var factor = UserDefaults.standard.double(forKey: "textZoomFactor")
        if factor == 0.0 {
            // If cannot retrieve value of textZoomFactor, use 1.0 as default value.
            factor = 1.0
        }
        webView.setTextZoomFactor(factor)
        self.view.addSubview(webView)
    }

    func load(withRequest request: URLRequest) {
        webView.load(request)
    }

    func load(withURLString url: String) {
        let request = URLRequest(url: URL(string: url)!)
        load(withRequest: request)
    }

    override func observeValue(forKeyPath keyPath: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
        if keyPath == "title" {
            self.view.window!.title = webView.title ?? ""
        }
    }

    func insertTextToTextarea(_ text: String) {
        let javascript = "insertText('\(text)');"
        webView.evaluateJavaScript(javascript, completionHandler: nil)
    }

    // MARK: Delegate - Called when the page title of a frame loads or changes.
    func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let event = NSApp.currentEvent {
            let commandKey: Bool = Int(event.modifierFlags.rawValue & NSCommandKeyMask.rawValue) != 0
            let mouseUp: Bool = event.type == NSLeftMouseUp
            if commandKey && mouseUp {
                // Open new window or tab with command key + click
                let doc = try! NSDocumentController.shared().openUntitledDocumentAndDisplay(false) as! Document
                doc.makeWindowControllersOnly()

                if #available(macOS 10.12, *) {
                    doc.windowControllers.first!.window!.tabbingMode = .preferred
                }
                doc.showWindows()
                let viewController: ViewController = doc.windowControllers.first!.contentViewController as! ViewController
                viewController.load(withRequest: navigationAction.request)

                // Cancel the loading webview in current window
                decisionHandler(.cancel)
                return
            }
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        NSWorkspace.shared().open(navigationAction.request.url!)
        return nil
    }

    func webView(_: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame _: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.alertStyle = NSAlertStyle.warning
        alert.runModal()
        completionHandler()
    }

    func webView(_: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame _: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = NSAlertStyle.warning
        if alert.runModal() == NSAlertFirstButtonReturn {
            return completionHandler(true)
        }
        return completionHandler(false)
    }
}
