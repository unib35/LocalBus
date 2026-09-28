import SwiftUI
import UIKit

// MARK: - 버스 알림 관리 (설정 → 버스 알림, 디자인 캔버스 MyAlerts)
//
// "오늘 한 번" / "평일마다 반복" 두 그룹. 행마다 토글, 왼쪽으로 밀어 삭제.

struct MyAlertsView: View {
    @ObservedObject var viewModel: MainViewModel
    var onAddFromTimetable: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var isPermissionDenied = false

    private var onceAlerts: [BusAlert] { viewModel.busAlerts.filter { !$0.repeatsWeekdays } }
    private var repeatAlerts: [BusAlert] { viewModel.busAlerts.filter(\.repeatsWeekdays) }

    var body: some View {
        ZStack {
            AmbientBackground()

            List {
                Group {
                    Text("버스 알림")
                        .font(AppTheme.Typography.screenTitle)
                        .foregroundStyle(AppTheme.Color.primaryText)
                        .frame(height: 44)
                        .padding(.top, 4)

                    if isPermissionDenied {
                        permissionCard
                            .padding(.top, 20)
                    }

                    if viewModel.busAlerts.isEmpty {
                        emptyState
                            .padding(.top, 20)
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if !onceAlerts.isEmpty {
                    alertSection(title: "오늘 한 번", alerts: onceAlerts)
                }
                if !repeatAlerts.isEmpty {
                    alertSection(title: "평일마다 반복", alerts: repeatAlerts)
                }

                Group {
                    if !viewModel.busAlerts.isEmpty {
                        Text("공휴일에는 울리지 않아요. 왼쪽으로 밀면 지울 수 있어요.")
                            .font(AppTheme.Typography.footnote)
                            .foregroundStyle(AppTheme.Color.tertiaryText)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                    }

                    Button {
                        dismiss()
                        onAddFromTimetable?()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .bold))
                            Text("시간표에서 알림 추가")
                        }
                    }
                    .buttonStyle(.secondaryAction)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 1)
        }
        .navigationTitle("")
        .legacyToolbarBackground(AppTheme.Color.screenBackground.opacity(0.95))
        .task {
            isPermissionDenied = await NotificationService.shared.authorizationStatus() == .denied
        }
    }

    // MARK: - 그룹

    @ViewBuilder
    private func alertSection(title: String, alerts: [BusAlert]) -> some View {
        Text(title)
            .font(AppTheme.Typography.caption.weight(.semibold))
            .foregroundStyle(AppTheme.Color.secondaryText)
            .padding(.horizontal, 4)
            .padding(.top, 24)
            .padding(.bottom, 8)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

        ForEach(Array(alerts.enumerated()), id: \.element.id) { index, alert in
            alertRow(alert, isFirst: index == 0, isLast: index == alerts.count - 1)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation { viewModel.removeAlert(id: alert.id) }
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
        }
    }

    private func alertRow(_ alert: BusAlert, isFirst: Bool, isLast: Bool) -> some View {
        let textColor = alert.isEnabled ? AppTheme.Color.primaryText : AppTheme.Color.secondaryText
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 14) {
                    Text(alert.busTime)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .tracking(-0.5)
                        .foregroundStyle(textColor)
                        .fixedSize()
                        .frame(minWidth: 62, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(alert.direction.displayName)
                            .font(AppTheme.Typography.rowBody)
                            .foregroundStyle(textColor)
                        Text(alert.detailText)
                            .font(AppTheme.Typography.caption)
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.Color.secondaryText)
                    }
                }
                .accessibilityElement(children: .combine)

                Spacer(minLength: 0)

                Toggle(
                    "\(alert.repeatsWeekdays ? "평일 " : "")\(alert.busTime) \(alert.direction.displayName) 알림",
                    isOn: Binding(
                        get: { alert.isEnabled },
                        set: { enabled in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.setAlertEnabled(id: alert.id, enabled)
                        }
                    )
                )
                .labelsHidden()
                .tint(AppTheme.Color.accent)
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 68)

            if !isLast {
                RowDivider()
            }
        }
        .background(AppTheme.Color.surface)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: isFirst ? AppTheme.Radius.surface : 0,
                bottomLeadingRadius: isLast ? AppTheme.Radius.surface : 0,
                bottomTrailingRadius: isLast ? AppTheme.Radius.surface : 0,
                topTrailingRadius: isFirst ? AppTheme.Radius.surface : 0,
                style: .continuous
            )
        )
    }

    // MARK: - 권한 / 빈 상태

    private var permissionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Color.nightFare)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text("알림이 꺼져 있어요")
                    .font(AppTheme.Typography.rowBody.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.primaryText)
                Text("iPhone 설정에서 알림을 허용해야 울려요")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            } label: {
                Text("설정 열기")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Capsule().fill(AppTheme.Color.secondaryButton))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 14)
        .surfaceCard()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("아직 버스 알림이 없어요")
                .font(AppTheme.Typography.rowBody.weight(.semibold))
                .foregroundStyle(AppTheme.Color.primaryText)
            Text("전체 시간표에서 버스를 누르면 몇 분 전에 알릴지 고를 수 있어요")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}

#Preview {
    NavigationStack {
        MyAlertsView(viewModel: MainViewModel())
    }
    .preferredColorScheme(.dark)
}
