//
//  RecurringReminderScheduler.swift
//  Swiftlet
//

import Foundation
import SwiftData
import UserNotifications

/// Keeps one pending local notification per active recurring rule, the day before it's due.
enum RecurringReminderScheduler {
    private static let identifierPrefix = "recurring-"
    static let reminderHour = 9

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    @MainActor
    static func reschedule(context: ModelContext, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        )

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let rules = (try? context.fetch(FetchDescriptor<RecurringTransaction>())) ?? []
        for rule in rules where rule.isActive && rule.remindsBeforeDue {
            guard let fireDate = reminderDate(for: rule.nextDueDate), fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = rule.type == .income ? "\(rule.title) arrives tomorrow" : "\(rule.title) is due tomorrow"
            content.body = "\(CurrencyFormatter.rupiah(rule.amount)) · \(rule.wallet?.name ?? "Main Wallet")"
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let request = UNNotificationRequest(
                identifier: identifierPrefix + String(describing: rule.persistentModelID.hashValue),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    private static func reminderDate(for dueDate: Date) -> Date? {
        let calendar = Calendar.current
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: dueDate)) else { return nil }
        return calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: dayBefore)
    }
}
