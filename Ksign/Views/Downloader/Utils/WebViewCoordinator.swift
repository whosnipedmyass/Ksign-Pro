//
//  WebViewCoordinator.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI
import WebKit

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private var parent: WebViewContainer
    private var isHandlingRedirect = false
    private var hasAddedScriptMessageHandler = false
    
    init(_ parent: WebViewContainer) {
        self.parent = parent
        super.init()
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        print("Navigation to: \(url.absoluteString)")
        
        if url.scheme == "itms-services" {
            decisionHandler(.cancel)
            parent.handleITMSURL(url)
            return
        }
        
        if parent.downloadManager.isFileURL(url) {
            decisionHandler(.cancel)
            parent.downloadDirectFile(url)
            return
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        isHandlingRedirect = true
        if let url = webView.url {
            print("Redirect to: \(url.absoluteString)")
            
            if url.scheme == "itms-services" {
                parent.handleITMSURL(url)
                return
            }
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        parent.isLoading = true
        isHandlingRedirect = false
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        parent.isLoading = false
        parent.title = webView.title ?? "Web Browser"
        
        let script = """
        (function() {
            function checkForItmsLink(element) {
                if (element.tagName === 'A' && element.href && element.href.indexOf('itms-services') !== -1) {
                    return element.href;
                }
                
                if (element.getAttribute && element.getAttribute('onclick')) {
                    var onclickValue = element.getAttribute('onclick');
                    if (onclickValue.indexOf('itms-services') !== -1) {
                        var matches = onclickValue.match(/['"]([^'"]*itms-services[^'"]*)['"]/);
                        if (matches && matches.length > 1) {
                            return matches[1];
                        }
                    }
                }
                
                if (element.dataset) {
                    for (var key in element.dataset) {
                        var value = element.dataset[key];
                        if (value && value.indexOf && value.indexOf('itms-services') !== -1) {
                            return value;
                        }
                    }
                }
                
                return null;
            }
            
            document.addEventListener('click', function(e) {
                var target = e.target;
                var itmsUrl = null;
                
                while(target && !itmsUrl) {
                    itmsUrl = checkForItmsLink(target);
                    if (!itmsUrl) {
                        target = target.parentNode;
                    }
                }
                
                if (itmsUrl) {
                    console.log('Detected itms-services URL:', itmsUrl);
                    window.webkit.messageHandlers.iosApp.postMessage(itmsUrl);
                    e.preventDefault();
                    e.stopPropagation();
                    return false;
                }
            }, true);
        })();
        """
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Error adding click handlers: \(error)")
            }
        }
        
        let windowOpenScript = """
        window.nativeOpen = window.open;
        window.open = function(url, target, features) {
            if (url) {
                window.webkit.messageHandlers.windowOpen.postMessage(url);
                return null;
            } else {
                return window.nativeOpen(url, target, features);
            }
        };
        """
        
        webView.evaluateJavaScript(windowOpenScript) { _, error in
            if let error = error {
                print("Error adding window.open handler: \(error)")
            }
        }
        
        if !hasAddedScriptMessageHandler {
            webView.configuration.userContentController.add(self, name: "iosApp")
            webView.configuration.userContentController.add(self, name: "windowOpen")
            hasAddedScriptMessageHandler = true
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }
    
    private func handleNavigationError(_ error: Error) {
        parent.isLoading = false
        
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        
        UIAlertController.showAlertWithOk(title: "Error", message: error.localizedDescription)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "iosApp", let urlString = message.body as? String, let url = URL(string: urlString) {
            print("JavaScript captured URL: \(urlString)")
            if url.scheme == "itms-services" {
                parent.handleITMSURL(url)
            }
        }
        else if message.name == "windowOpen", let urlString = message.body as? String {
            print("window.open called with URL: \(urlString)")
            
            var url: URL?
            if let absoluteURL = URL(string: urlString) {
                url = absoluteURL
            } else if let baseURL = parent.webView.url, let relativeURL = URL(string: urlString, relativeTo: baseURL) {
                url = relativeURL
            }
            
            if let validURL = url {
                handleWindowOpen(validURL)
            }
        }
    }
    
    private func handleWindowOpen(_ url: URL) {
        if url.scheme == "itms-services" {
            parent.handleITMSURL(url)
            return
        }
        
        if parent.downloadManager.isFileURL(url) {
            parent.downloadDirectFile(url)
            return
        }
        
        let request = URLRequest(url: url)
        parent.webView.load(request)
    }
    
    deinit {
        parent.webView.configuration.userContentController.removeScriptMessageHandler(forName: "iosApp")
        parent.webView.configuration.userContentController.removeScriptMessageHandler(forName: "windowOpen")
    }
} 