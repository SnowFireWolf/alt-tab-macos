import Cocoa

class FeedbackWindow: NSWindow {
    static let token = Bundle.main.object(forInfoDictionaryKey: "FeedbackToken") as! String
    var body: TextArea!
    var email: TextArea!
    var sendButton: NSButton!
    var debugProfile: NSButton!

    override init(contentRect: NSRect, styleMask style: StyleMask, backing backingStoreType: BackingStoreType, defer flag: Bool) {
        super.init(contentRect: .zero, styleMask: style, backing: backingStoreType, defer: flag)
        setupWindow()
        setupView()
    }

    func show() {
        App.shared.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    private func setupWindow() {
        title = NSLocalizedString("Send feedback", comment: "")
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        styleMask.insert([.miniaturizable, .closable])
    }

    private func setupView() {
        let appIcon = NSImageView(image: NSImage(named: "app-icon")!.resizedCopy(80, 80))
        appIcon.imageScaling = .scaleNone
        let appText = NSStackView(views: [
            BoldLabel(NSLocalizedString("Share improvement ideas, or report bugs", comment: "")),
            HyperlinkLabel(NSLocalizedString("View existing discussions", comment: ""), App.repository + "/issues"),
        ])
        appText.orientation = .vertical
        appText.alignment = .left
        appText.spacing = GridView.interPadding / 2
        let header = NSStackView(views: [appIcon, appText])
        header.spacing = GridView.interPadding
        sendButton = NSButton(title: NSLocalizedString("Send", comment: ""), target: nil, action: #selector(sendCallback))
        sendButton.keyEquivalent = "\r"
        sendButton.isEnabled = false
        let buttons = NSStackView(views: [
            NSButton(title: NSLocalizedString("Cancel", comment: ""), target: nil, action: #selector(cancelCallback)),
            sendButton,
        ])
        buttons.spacing = GridView.interPadding
        body = TextArea(80, 12, NSLocalizedString("I think the app could be improved with…", comment: ""), { () -> Void in
            self.sendButton.isEnabled = !self.body.stringValue.isEmpty
        })
        email = TextArea(80, 1, NSLocalizedString("Optional: email (if you want a reply)", comment: ""))
        debugProfile = NSButton(checkboxWithTitle: NSLocalizedString("Send debug profile (CPU, memory, etc)", comment: ""), target: nil, action: nil)
        debugProfile.state = .on
        let view = GridView([
            [header],
            [body],
            [email],
            [debugProfile],
            [buttons],
        ])
        view.cell(atColumnIndex: 0, rowIndex: 4).xPlacement = .trailing
        setContentSize(view.fittingSize)
        contentView = view
    }

    @objc private func cancelCallback() {
        close()
    }

    @objc private func sendCallback() {
        if email.stringValue.isEmpty && !warnAboutNoEmail() {
            return
        }
        openTicket()
    }

    func openTicket() {
        URLSession.shared.dataTask(with: prepareRequest(), completionHandler: { data, response, error in
            if error != nil || response == nil || (response as! HTTPURLResponse).statusCode != 201 {
                debugPrint("HTTP call failed:", response ?? "nil", error ?? "nil")
            }
        }).resume()
        close()
    }

    func warnAboutNoEmail() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Are you sure you don’t want a response?", comment: "")
        alert.informativeText = NSLocalizedString("You didn’t write your email, thus can’t receive any response.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Send anyway", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        return alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
    }

    private func prepareRequest() -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/lwouis/alt-tab-macos/issues")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        // access token of the alt-tab-macos-bot github account, with scope repo > public_repo
        request.addValue("token " + FeedbackWindow.token, forHTTPHeaderField: "Authorization")
        request.httpBody = try! JSONSerialization.data(withJSONObject: [
            "title": "[In-app feedback]",
            "body": assembleBody()
        ])
        return request
    }

    private func assembleBody() -> String {
        var result = ""
        result += "_This issue was opened by a bot after a user submitted feedback through the in-app form._"
        if !email.stringValue.isEmpty {
            result += "\n\n__From:__ " + email.stringValue
        }
        result += "\n\n__Message:__"
        result += "\n\n> " + body.stringValue.replacingOccurrences(of: "\n", with: "\n> ")
        if debugProfile.state == .on {
            result += "\n\n<details>\n<summary><strong>Debug profile</strong></summary>\n<p>"
            result += "\n\n" + DebugProfile.make()
            result += "\n\n" + "</p>\n</details>"
        }
        return result
    }
}
