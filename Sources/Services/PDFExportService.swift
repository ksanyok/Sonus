import Foundation
import WebKit
import AppKit

class PDFExportService {
    static let shared = PDFExportService()
    
    private init() {}
    
    func exportPDF(for session: Session, completion: @escaping (URL?) -> Void) {
        let html = generateHTML(for: session)
        
        let printOpts = NSPrintInfo.shared.dictionary() as! [NSPrintInfo.AttributeKey: Any]
        let printInfo = NSPrintInfo(dictionary: printOpts)
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.topMargin = 50
        printInfo.bottomMargin = 50
        printInfo.leftMargin = 50
        printInfo.rightMargin = 50
        
        // Create a hidden WebView to render HTML
        let webView = WebView(frame: NSRect(x: 0, y: 0, width: 595, height: 842)) // A4 size points
        webView.mainFrame.loadHTMLString(html, baseURL: nil)
        
        // Wait for load (hacky but standard for headless webview)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let printOperation = NSPrintOperation(view: webView.mainFrame.frameView.documentView, printInfo: printInfo)
            printOperation.showsPrintPanel = false
            printOperation.showsProgressPanel = false
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Report_\(session.date.formatted(date: .numeric, time: .omitted)).pdf")
            
            // Save to PDF
            // macOS WebKit printing is tricky to redirect to file without user interaction if using standard print operation.
            // Better approach: use dataFromPDF inside the view.
            
            let data = webView.dataWithPDF(inside: webView.bounds)
            do {
                try data.write(to: tempURL)
                completion(tempURL)
            } catch {
                print("PDF Write Error: \(error)")
                completion(nil)
            }
        }
    }
    
    private func generateHTML(for session: Session) -> String {
        let title = session.customTitle ?? "Conversation Report"
        let date = session.date.formatted(date: .long, time: .shortened)
        let summary = session.analysis?.summary ?? "No summary available."
        let score = session.analysis?.score ?? 0
        
        var actionItemsHTML = ""
        if let items = session.analysis?.actionItems {
            for item in items {
                actionItemsHTML += "<li><strong>\(item.title)</strong> (Owner: \(item.owner ?? "-"))<br><em>\(item.notes ?? "")</em></li>"
            }
        }
        
        var keyMomentsHTML = ""
        if let moments = session.analysis?.keyMoments {
            for moment in moments {
                let color = moment.severity == "critical" ? "red" : (moment.severity == "warning" ? "orange" : "black")
                keyMomentsHTML += """
                <div style="margin-bottom: 10px; border-left: 3px solid \(color); padding-left: 10px;">
                    <div style="font-size: 12px; color: #666;">\(moment.timeHint ?? "") - \(moment.type ?? "Moment")</div>
                    <div>"\(moment.text)"</div>
                    <div style="font-style: italic; color: #444; margin-top: 4px;">💡 \(moment.recommendation ?? "")</div>
                </div>
                """
            }
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { font-family: -apple-system, Helvetica, Arial, sans-serif; line-height: 1.5; color: #333; max-width: 700px; margin: 0 auto; }
                h1 { border-bottom: 2px solid #eee; padding-bottom: 10px; }
                h2 { margin-top: 30px; color: #0066cc; }
                .meta { color: #666; margin-bottom: 30px; }
                .score-box { float: right; background: #f0f0f0; padding: 10px 20px; border-radius: 8px; text-align: center; }
                .score-val { font-size: 24px; font-weight: bold; display: block; }
                .section { margin-bottom: 20px; }
                ul { padding-left: 20px; }
                li { margin-bottom: 8px; }
            </style>
        </head>
        <body>
            <div class="score-box">
                <span class="score-val">\(score)/100</span>
                <span>Score</span>
            </div>
            
            <h1>\(title)</h1>
            <div class="meta">\(date)</div>
            
            <div class="section">
                <h2>Executive Summary</h2>
                <p>\(summary)</p>
            </div>
            
            <div class="section">
                <h2>Action Items</h2>
                <ul>\(actionItemsHTML)</ul>
            </div>
            
            <div class="section">
                <h2>Key Moments & Recommendations</h2>
                \(keyMomentsHTML)
            </div>
        </body>
        </html>
        """
    }
}
