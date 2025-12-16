import Foundation
import WebKit
import AppKit

class PDFExportService {
    static let shared = PDFExportService()
    
    private init() {}
    
    func exportPDF(for session: Session, to url: URL, completion: @escaping (Bool) -> Void) {
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
        // Ensure UI operations are on main thread
        DispatchQueue.main.async {
            let webView = WebView(frame: NSRect(x: 0, y: 0, width: 595, height: 842)) // A4 size points
            webView.mainFrame.loadHTMLString(html, baseURL: nil)
            
            // Wait for load (hacky but standard for headless webview)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let data = webView.dataWithPDF(inside: webView.bounds)
                do {
                    try data.write(to: url)
                    completion(true)
                } catch {
                    print("PDF Write Error: \(error)")
                    completion(false)
                }
            }
        }
    }
    
    private func generateHTML(for session: Session) -> String {
        let title = session.customTitle ?? "Conversation Report"
        let date = session.date.formatted(date: .long, time: .shortened)
        let summary = session.analysis?.summary ?? "No summary available."
        let score = session.analysis?.score ?? 0
        let engagement = session.analysis?.engagementScore ?? 0
        let salesProb = session.analysis?.salesProbability ?? 0
        
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
        
        var speakersHTML = ""
        if let speakers = session.analysis?.speakerInsights {
            for speaker in speakers {
                var strengthsHTML = ""
                if let strengths = speaker.strengths {
                    strengthsHTML = "<ul>" + strengths.map { "<li>\($0)</li>" }.joined() + "</ul>"
                }
                
                var risksHTML = ""
                if let risks = speaker.risks {
                    risksHTML = "<ul>" + risks.map { "<li>\($0)</li>" }.joined() + "</ul>"
                }
                
                speakersHTML += """
                <div class="speaker-card">
                    <h3>\(speaker.name) <span style="font-size: 14px; color: #666; font-weight: normal;">(\(speaker.role ?? "Unknown"))</span></h3>
                    <div style="display: flex; gap: 20px; margin-bottom: 10px;">
                        <div>Activity: <strong>\(speaker.activityScore ?? 0)%</strong></div>
                        <div>Competence: <strong>\(speaker.competenceScore ?? 0)%</strong></div>
                        <div>Emotion: <strong>\(speaker.emotionControlScore ?? 0)%</strong></div>
                    </div>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">
                        <div><strong>Strengths:</strong>\(strengthsHTML)</div>
                        <div><strong>Risks:</strong>\(risksHTML)</div>
                    </div>
                </div>
                """
            }
        }
        
        var guidanceHTML = ""
        if let guidance = session.analysis?.managerGuidance {
            if let advice = guidance.generalAdvice, !advice.isEmpty {
                guidanceHTML += "<h4>General Advice</h4><ul>" + advice.map { "<li>\($0)</li>" }.joined() + "</ul>"
            }
            if let scenarios = guidance.alternativeScenarios, !scenarios.isEmpty {
                guidanceHTML += "<h4>Alternative Scenarios</h4><ul>" + scenarios.map { "<li>\($0)</li>" }.joined() + "</ul>"
            }
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { font-family: -apple-system, Helvetica, Arial, sans-serif; line-height: 1.5; color: #333; max-width: 700px; margin: 0 auto; padding: 40px; }
                h1 { border-bottom: 2px solid #eee; padding-bottom: 10px; margin-bottom: 5px; }
                h2 { margin-top: 30px; color: #0066cc; border-bottom: 1px solid #eee; padding-bottom: 5px; }
                h3 { margin-top: 20px; margin-bottom: 10px; }
                h4 { margin-top: 15px; margin-bottom: 5px; font-size: 16px; }
                .meta { color: #666; margin-bottom: 30px; font-size: 14px; }
                .metrics-row { display: flex; gap: 20px; margin-bottom: 30px; background: #f9f9f9; padding: 15px; border-radius: 8px; }
                .metric { text-align: center; flex: 1; }
                .metric-val { font-size: 24px; font-weight: bold; display: block; color: #0066cc; }
                .metric-label { font-size: 12px; color: #666; text-transform: uppercase; }
                .section { margin-bottom: 20px; }
                ul { padding-left: 20px; margin-top: 5px; }
                li { margin-bottom: 6px; }
                .speaker-card { background: #fff; border: 1px solid #eee; padding: 15px; border-radius: 8px; margin-bottom: 15px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
            </style>
        </head>
        <body>
            <h1>\(title)</h1>
            <div class="meta">\(date) • \(session.category.displayNameEn)</div>
            
            <div class="metrics-row">
                <div class="metric">
                    <span class="metric-val">\(score)</span>
                    <span class="metric-label">Overall Score</span>
                </div>
                <div class="metric">
                    <span class="metric-val">\(engagement)%</span>
                    <span class="metric-label">Engagement</span>
                </div>
                <div class="metric">
                    <span class="metric-val">\(salesProb)%</span>
                    <span class="metric-label">Sales Prob.</span>
                </div>
            </div>
            
            <div class="section">
                <h2>Executive Summary</h2>
                <p>\(summary)</p>
            </div>
            
            <div class="section">
                <h2>Action Items</h2>
                <ul>\(actionItemsHTML)</ul>
            </div>
            
            <div class="section">
                <h2>Speaker Analysis</h2>
                \(speakersHTML)
            </div>
            
            <div class="section">
                <h2>Manager Guidance</h2>
                \(guidanceHTML)
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
