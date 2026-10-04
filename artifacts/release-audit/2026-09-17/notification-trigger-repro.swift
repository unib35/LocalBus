// 실행: swift notification-trigger-repro.swift
// NotificationService.swift의 시/분 조립을 재현합니다.
// OS에 알림을 등록하거나 발송하지 않고 다음 일치 시각만 계산합니다.
import Foundation
import UserNotifications

let now = Date()
let calendar = Calendar.current
let departure = calendar.date(byAdding: .minute, value: 2, to: now)!
var components = DateComponents()
components.hour = calendar.component(.hour, from: departure)
components.minute = calendar.component(.minute, from: departure) - 5
if components.minute! < 0 {
    components.hour! -= 1
    components.minute! += 60
}
let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
if let next = trigger.nextTriggerDate() {
    print("출발까지: 2분, 실제 알림 예약까지:", Int(next.timeIntervalSince(now) / 60), "분")
} else {
    print("다음 알림 시각 없음")
}
