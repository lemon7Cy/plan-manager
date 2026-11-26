//
//  PlanManagerApp.swift
//  Plan Manager
//
//  iOS 26 Liquid Glass Design
//

import SwiftUI

@main
struct PlanManagerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var themeManager = ThemeManager()
    @State private var notificationManager = NotificationManager()
    @State private var quickActionManager = QuickActionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .environment(notificationManager)
                .environment(quickActionManager)
                .preferredColorScheme(themeManager.currentTheme.colorScheme)
                .onAppear {
                    // 1. Request Notification Auth
                    Task {
                        _ = await notificationManager.requestAuthorization()
                    }

                    // 2. Handle Cold Start Quick Action
                    // The notification might have fired before view loaded, so check manually.
                    if let item = QuickActionBuffer.shared.pendingShortcutItem {
                        quickActionManager.handleShortcutItem(item)
                        QuickActionBuffer.shared.pendingShortcutItem = nil
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .didReceiveQuickAction)) { _ in
                    if let item = QuickActionBuffer.shared.pendingShortcutItem {
                        quickActionManager.handleShortcutItem(item)
                        QuickActionBuffer.shared.pendingShortcutItem = nil // Consume
                    }
                }
        }
    }
}

// MARK: - Notification Manager

import UserNotifications

@MainActor
@Observable
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    var isAuthorized = false
    var dailyReminderEnabled = false
    var sleepReminderEnabled = false
    var waterReminderEnabled = false
    var hourlyReminderEnabled = false
    var dailyReminderTime = Date() // Default will be set in init
    var sleepReminderTime = Date()
    var waterStartHour: Int = 9
    var waterInterval: Int = 120 // Minutes

    var nickname: String = "您"
    private var lastPlanReminderSignature: String?

    var waterEndHour: Int { 22 }

    override init() {
        super.init()

        // Set delegate
        UNUserNotificationCenter.current().delegate = self

        reloadSettings()
        checkAuthorization()
    }

    // MARK: - Delegate Methods

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even if app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                self.isAuthorized = (status == .authorized)
            }
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { self.isAuthorized = granted }
            return granted
        } catch {
            return false
        }
    }

    func updateNickname(_ name: String) {
        guard !name.isEmpty, name != nickname else { return }
        nickname = name
        UserDefaults.standard.set(name, forKey: StorageKeys.nickname)

        // Refresh reminders that use nickname
        if waterReminderEnabled {
            scheduleWaterReminders()
        }
        if hourlyReminderEnabled {
            lastPlanReminderSignature = nil
            scheduleHourlyPlanReminders()
        }
    }

    func toggleHourlyReminder(_ enabled: Bool) {
        hourlyReminderEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: StorageKeys.hourlyReminderEnabled)
        lastPlanReminderSignature = nil

        if enabled {
            // Hourly reminders depend on today's plan state. Actual scheduling is driven
            // by PlanView after plans are loaded/synced for the selected day.
            cancelHourlyPlanReminders()
        } else {
            cancelHourlyPlanReminders()
        }
    }

    func updatePlanCompletionStatus(planCount: Int, isAllCompleted: Bool) {
        let signature = "\(hourlyReminderEnabled)-\(isAuthorized)-\(planCount)-\(isAllCompleted)"
        guard signature != lastPlanReminderSignature else { return }
        lastPlanReminderSignature = signature

        guard hourlyReminderEnabled else {
            cancelHourlyPlanReminders()
            return
        }

        // No plans today: no hourly "unfinished" reminders should exist.
        guard planCount > 0 else {
            cancelHourlyPlanReminders()
            return
        }

        if isAllCompleted {
            cancelHourlyPlanReminders()
        } else {
            scheduleHourlyPlanReminders()
        }
    }

    func updatePlanCompletionStatus(isAllCompleted: Bool) {
        // Backward-compatible wrapper. Treat unknown plan count as 1.
        updatePlanCompletionStatus(planCount: 1, isAllCompleted: isAllCompleted)
    }

    func toggleDailyReminder(_ enabled: Bool) {
        dailyReminderEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: StorageKeys.dailyReminderEnabled)
        if enabled { scheduleDailyReminder() }
        else { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_plan"]) }
    }

    func setDailyReminderTime(_ date: Date) {
        dailyReminderTime = date
        UserDefaults.standard.set(date, forKey: StorageKeys.dailyReminderTime)
        if dailyReminderEnabled { scheduleDailyReminder() }
    }

    func toggleSleepReminder(_ enabled: Bool) {
        sleepReminderEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: StorageKeys.sleepReminderEnabled)
        if enabled { scheduleSleepReminder() }
        else { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["sleep_reminder"]) }
    }

    func setSleepReminderTime(_ date: Date) {
        sleepReminderTime = date
        UserDefaults.standard.set(date, forKey: StorageKeys.sleepReminderTime)
        if sleepReminderEnabled { scheduleSleepReminder() }
    }

    func toggleWaterReminder(_ enabled: Bool) {
        waterReminderEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: StorageKeys.waterReminderEnabled)
        if enabled {
            refreshWaterReminderRandomSeed()
            scheduleWaterReminders()
        }
        else { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: waterReminderIdentifiersForCleanup()) }
    }

    func updateWaterSettings(startHour: Int, intervalMinutes: Int) {
        waterStartHour = startHour
        waterInterval = intervalMinutes

        UserDefaults.standard.set(startHour, forKey: StorageKeys.waterStartHour)
        UserDefaults.standard.set(intervalMinutes, forKey: StorageKeys.waterInterval)

        if waterReminderEnabled {
            refreshWaterReminderRandomSeed()
            scheduleWaterReminders()
        }
    }

    func reloadSettings() {
        dailyReminderEnabled = UserDefaults.standard.bool(forKey: StorageKeys.dailyReminderEnabled)
        sleepReminderEnabled = UserDefaults.standard.bool(forKey: StorageKeys.sleepReminderEnabled)
        waterReminderEnabled = UserDefaults.standard.bool(forKey: StorageKeys.waterReminderEnabled)
        hourlyReminderEnabled = UserDefaults.standard.bool(forKey: StorageKeys.hourlyReminderEnabled)
        nickname = LocalStorage.shared.nickname

        waterStartHour = UserDefaults.standard.integer(forKey: StorageKeys.waterStartHour)
        if waterStartHour == 0 { waterStartHour = 9 }

        waterInterval = UserDefaults.standard.integer(forKey: StorageKeys.waterInterval)
        if waterInterval == 0 { waterInterval = 120 }

        if let dTime = UserDefaults.standard.object(forKey: StorageKeys.dailyReminderTime) as? Date {
            dailyReminderTime = dTime
        } else {
            var components = DateComponents()
            components.hour = 9
            components.minute = 0
            dailyReminderTime = Calendar.current.date(from: components) ?? Date()
        }

        if let sTime = UserDefaults.standard.object(forKey: StorageKeys.sleepReminderTime) as? Date {
            sleepReminderTime = sTime
        } else {
            var components = DateComponents()
            components.hour = 23
            components.minute = 0
            sleepReminderTime = Calendar.current.date(from: components) ?? Date()
        }

        if dailyReminderEnabled { scheduleDailyReminder() }
        if sleepReminderEnabled { scheduleSleepReminder() }
        if waterReminderEnabled { scheduleWaterReminders() }
    }

    // MARK: - Scheduling Logic

    private func scheduleDailyReminder() {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "早安，\(nickname) ☀️"
        content.body = "新的一天开始了，快来规划今天的任务吧！✨"
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: dailyReminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: "daily_plan", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleSleepReminder() {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "晚安，\(nickname) 🌙"
        content.body = "忙碌了一天辛苦了，即使计划没完成也要注意休息哦。"
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: sleepReminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: "sleep_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleWaterReminders() {
        guard isAuthorized else { return }

        // Remove old identifiers first to be clean
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: waterReminderIdentifiersForCleanup())

        let content = UNMutableNotificationContent()
        content.title = "\(nickname)，该喝水了 💧"
        content.body = "已经很久没喝水了，补充水分保持活力！"
        content.sound = .default

        for reminderTime in randomizedWaterReminderTimes() {
            var components = DateComponents()
            components.hour = reminderTime.hour
            components.minute = reminderTime.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "water_\(reminderTime.hour)_\(reminderTime.minute)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func scheduleHourlyPlanReminders() {
        guard isAuthorized else { return }
        cancelHourlyPlanReminders()
        // 10:00 to 20:00 every 1 hour
        let content = UNMutableNotificationContent()
        content.title = "计划未完成提醒 ⏳"
        content.body = "\(nickname)，别忘了完成今天的计划哦！"
        content.sound = .default

        for hour in 10...20 {
            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "hourly_plan_\(hour)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func cancelHourlyPlanReminders() {
        let ids = (10...20).map { "hourly_plan_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func waterReminderIdentifiersForCleanup() -> [String] {
        let legacy = (0..<24).map { "water_\($0)" }
        let current = (0...23).flatMap { hour in
            (0..<60).map { minute in
                "water_\(hour)_\(minute)"
            }
        }
        return legacy + current
    }

    private func randomizedWaterReminderTimes() -> [(hour: Int, minute: Int)] {
        let startMinute = max(0, min(waterStartHour, waterEndHour - 1)) * 60
        let endMinute = waterEndHour * 60
        let interval = max(15, waterInterval)
        let jitterRange = max(5, min(22, interval / 3))
        var generator = SeededRandomNumberGenerator(seed: waterReminderRandomSeed())
        var result: [(hour: Int, minute: Int)] = []
        var baseMinute = startMinute

        while baseMinute < endMinute {
            let offset = Int.random(in: -jitterRange...jitterRange, using: &generator)
            var scheduledMinute = max(startMinute + 3, min(endMinute - 1, baseMinute + offset))
            if scheduledMinute % 60 == 0 {
                let direction = Bool.random(using: &generator) ? 1 : -1
                scheduledMinute = max(startMinute + 3, min(endMinute - 1, scheduledMinute + direction * Int.random(in: 4...11, using: &generator)))
            }

            let hour = scheduledMinute / 60
            let minute = scheduledMinute % 60
            if result.last?.hour != hour || result.last?.minute != minute {
                result.append((hour, minute))
            }

            baseMinute += interval
            if result.count >= 20 { break }
        }

        return result
    }

    private func waterReminderRandomSeed() -> UInt64 {
        let existing = UserDefaults.standard.integer(forKey: StorageKeys.waterReminderRandomSeed)
        if existing > 0 { return UInt64(existing) }
        return UInt64(refreshWaterReminderRandomSeed())
    }

    @discardableResult
    private func refreshWaterReminderRandomSeed() -> Int {
        let seed = Int.random(in: 1...(Int.max / 2))
        UserDefaults.standard.set(seed, forKey: StorageKeys.waterReminderRandomSeed)
        return seed
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
// MARK: - Quick Action Manager

import UIKit

enum QuickAction: String, Hashable {
    case addPlan = "com.planmanager.addPlan"
    case addExpense = "com.planmanager.addExpense"
}

@MainActor
@Observable
class QuickActionManager {
    var action: QuickAction?

    func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        if let type = QuickAction(rawValue: shortcutItem.type) {
            self.action = type
        }
    }
}

// MARK: - App Delegate Adaptor
class AppDelegate: NSObject, UIApplicationDelegate {
    var quickActionManager: QuickActionManager?

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Handle Action if launched from shortcut
        if let shortcutItem = options.shortcutItem {
            // We need to pass this to the manager later, or store it temporarily?
            // Since Manager is created in App, and AppDelegate is created before App body...
            // Wait, we can't easily access Manager here unless it's static or injected later.
            // Better strategy: Store it in a static var or handle in scene delegate.
            // But SwiftUI handles lifecycle.

            // Simplest hack: NotificationCenter or Singleton
            // Or, rely on the fact that `performActionFor shortcutItem` is called for background apps?
            // For cold launch, `options.shortcutItem` is key.

            // Let's store it static to retrieval
            QuickActionBuffer.shared.pendingShortcutItem = shortcutItem
        }

        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        QuickActionBuffer.shared.pendingShortcutItem = shortcutItem
        completionHandler(true)
    }
}

// Helper to bridge UIKit to SwiftUI
@MainActor
class QuickActionBuffer {
    static let shared = QuickActionBuffer()
    var pendingShortcutItem: UIApplicationShortcutItem? {
        didSet {
            // Notify observers if needed, or simply let SwiftUI poll it
            // We will hook this up in PlanManagerApp
            NotificationCenter.default.post(name: .didReceiveQuickAction, object: nil)
        }
    }
}

extension Notification.Name {
    static let didReceiveQuickAction = Notification.Name("didReceiveQuickAction")
}
