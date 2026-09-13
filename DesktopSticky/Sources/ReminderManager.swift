import AppKit
import Foundation
import UserNotifications

/// 提醒设置弹窗：15 分钟 / 1 小时 / 明早 快捷项 + 自定义日期时间 + 设置/清除
final class ReminderPopoverViewController: NSViewController {

    let noteID: String
    var onSetReminder: ((Date) -> Void)?
    var onClearReminder: (() -> Void)?

    var currentDate: Date?

    private let datePicker = NSDatePicker()
    private let infoLabel = NSTextField(labelWithString: "")
    private let setButton = NSButton(title: "设置", target: nil, action: nil)
    private let clearButton = NSButton(title: "清除提醒", target: nil, action: nil)

    init(noteID: String) {
        self.noteID = noteID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 208))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    private func buildUI() {
        let title = NSTextField(labelWithString: "设置提醒")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        // 快捷项
        let quickStack = NSStackView()
        quickStack.orientation = .horizontal
        quickStack.spacing = 8
        quickStack.translatesAutoresizingMaskIntoConstraints = false
        let quickItems: [(String, TimeInterval?)] = [
            ("15 分钟", 15 * 60),
            ("1 小时", 60 * 60),
            ("明早", nil),
        ]
        for (label, interval) in quickItems {
            let b = NSButton(title: label, target: self, action: #selector(quickTap(_:)))
            b.bezelStyle = .rounded
            b.controlSize = .small
            b.tag = interval == nil ? -999 : Int(interval!)
            quickStack.addArrangedSubview(b)
        }

        // 日期时间选择器
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.datePickerElements = [.yearMonthDay, .hourMinute]
        datePicker.datePickerMode = .single
        datePicker.translatesAutoresizingMaskIntoConstraints = false

        infoLabel.font = .systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.translatesAutoresizingMaskIntoConstraints = false

        // 操作按钮
        setButton.target = self
        setButton.action = #selector(setTap(_:))
        setButton.bezelStyle = .rounded
        setButton.keyEquivalent = "\r"

        clearButton.target = self
        clearButton.action = #selector(clearTap(_:))
        clearButton.bezelStyle = .rounded

        let btnRow = NSStackView(views: [clearButton, setButton])
        btnRow.orientation = .horizontal
        btnRow.spacing = 8
        btnRow.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(title)
        view.addSubview(quickStack)
        view.addSubview(datePicker)
        view.addSubview(infoLabel)
        view.addSubview(btnRow)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            quickStack.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            quickStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            datePicker.topAnchor.constraint(equalTo: quickStack.bottomAnchor, constant: 12),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            infoLabel.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 10),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            btnRow.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 12),
            btnRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            btnRow.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
        ])
    }

    func refreshUI() {
        if let d = currentDate {
            datePicker.dateValue = d
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "M月d日 HH:mm"
            infoLabel.stringValue = "当前提醒：\(f.string(from: d))"
        } else {
            datePicker.dateValue = Date().addingTimeInterval(15 * 60)
            infoLabel.stringValue = "未设置提醒"
        }
    }

    @objc private func quickTap(_ sender: NSButton) {
        var target: Date
        if sender.tag == -999 {
            // 明早 9 点
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.day! += 1
            comps.hour = 9
            comps.minute = 0
            target = Calendar.current.date(from: comps)!
        } else {
            target = Date().addingTimeInterval(TimeInterval(sender.tag))
        }
        onSetReminder?(target)
        dismiss(nil)
    }

    @objc private func setTap(_ sender: Any?) {
        let target = datePicker.dateValue
        // 时间已过则顺延到次日同一时刻
        var t = target
        if t <= Date() {
            t = t.addingTimeInterval(24 * 3600)
        }
        onSetReminder?(t)
        dismiss(nil)
    }

    @objc private func clearTap(_ sender: Any?) {
        onClearReminder?()
        dismiss(nil)
    }
}

/// 提醒调度与 macOS 系统通知
final class ReminderManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = ReminderManager()
    static let categoryID = "REMINDER_CATEGORY"
    static let actionFocus = "FOCUS_NOTE"

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                NSLog("通知授权失败: %@", error.localizedDescription)
            }
        }
    }

    func schedule(for note: Note) {
        guard let ms = note.reminderAt else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [note.id])

        let content = UNMutableNotificationContent()
        content.title = "Deskbit"
        let body = note.content.isEmpty ? "到点提醒" : note.content
        content.body = "Remember: \(body)"
        content.sound = .default
        content.userInfo = ["noteID": note.id]
        content.categoryIdentifier = Self.categoryID

        let date = Date(timeIntervalSince1970: ms / 1000)
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: note.id, content: content, trigger: trigger)
        center.add(request)
    }

    func cancel(for note: Note?) {
        guard let note = note else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [note.id])
    }

    /// 按便签 ID 移除未触发的提醒（删除便签时使用）
    func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// 启动时重建所有待触发的提醒
    func rescheduleAll() {
        for note in NoteStore.shared.notes {
            if note.reminderAt != nil, note.reminderFiredAt == nil {
                schedule(for: note)
            }
        }
    }

    /// 通知即将展示（应用在前台时也显示）
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    /// 记录提醒已触发
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let noteID = userInfo["noteID"] as? String {
            if let idx = NoteStore.shared.notes.firstIndex(where: { $0.id == noteID }) {
                var note = NoteStore.shared.notes[idx]
                note.reminderFiredAt = Date().timeIntervalSince1970 * 1000
                NoteStore.shared.update(note)
            }
            if response.actionIdentifier == Self.actionFocus {
                AppDelegate.shared.showNote(id: noteID)
            }
        }
        completionHandler()
    }
}
