import SwiftUI
import WebKit

struct HTMLArtifactView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let wrapped = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                :root {
                    color-scheme: light dark;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    padding: 16px;
                    margin: 0;
                    color: #e0e0e0;
                    background: transparent;
                }
                @media (prefers-color-scheme: light) {
                    body { color: #1a1a1a; }
                }
                pre {
                    background: rgba(128,128,128,0.1);
                    border-radius: 6px;
                    padding: 12px;
                    overflow-x: auto;
                }
                code {
                    font-family: 'SF Mono', Menlo, monospace;
                    font-size: 13px;
                }
                a { color: #4a9eff; }
                table { border-collapse: collapse; width: 100%; }
                th, td { border: 1px solid rgba(128,128,128,0.3); padding: 8px; text-align: left; }
            </style>
        </head>
        <body>\(html)</body>
        </html>
        """
        webView.loadHTMLString(wrapped, baseURL: nil)
    }
}
