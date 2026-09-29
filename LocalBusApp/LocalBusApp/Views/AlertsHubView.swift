import SwiftUI

// MARK: - 알림 모아보기 (디자인 캔버스 AlertsHub)
//
// 앱이 보낸 알림 전체를 날짜별로 모은 화면. 종류 칩으로 거르고, 항목을 누르면 버스 상세·공지·시간표로 간다.

struct AlertsHubView: View {
    private enum Filter: String, CaseIterable, Identifiable {
        case all = "전체"
        case bus = "버스 출발"
        case notice = "공지"
        case timetable = "시간표"
        var id: String { rawValue }

        func matches(_ kind: AppNotificationKind) -> Bool {
            switch self {
            case .all: return true
            case .bus: return kind == .bus || kind == .lastBus
            case .notice: return kind == .notice
            case .timetable: return kind == .timetable
            }
        }
    }

    @ObservedObject var viewModel: MainViewModel
    var onShowTimetable: (() -> Void)? = nil

    @ObservedObject private var history = NotificationHistoryStore.shared
    @EnvironmentObject private var storeService: StoreService
    @State private var filter: Filter = .all
    @State private var busDetail: BusDetailInfo?
    @State private var noticeToOpen: NoticeItem?
    @State private var showNoticeList = false
    @State private var showPaywall = false

    private var visibleItems: [AppNotification] {
        history.items.filter { filter.matches($0.kind) }
    }

    private var groups: [(day: String, items: [AppNotification])] {
        var order: [String] = []
        var grouped: [String: [AppNotification]] = [:]
        for item in visibleItems {
            let day = NotificationHistoryStore.dayLabel(for: item.receivedAt)
            if grouped[day] == nil { order.append(day) }
            grouped[day, default: []].append(item)
        }
        return order.map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("알림")
                            .font(AppTheme.Typography.screenTitle)
                            .foregroundStyle(AppTheme.Color.primaryText)
                        if !history.items.isEmpty {
                            Text(history.unreadCount > 0 ? "읽지 않음 \(history.unreadCount)개" : "모두 읽었어요")
                                .font(.system(size: 14, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.Color.secondaryText)
                        }
                    }
                    .frame(height: 44)
                    .padding(.top, 4)

                    if history.items.isEmpty {
                        emptyState
                            .padding(.top, 20)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Filter.allCases) { option in
                                    SelectableChip(title: option.rawValue, isSelected: option == filter, height: 40) {
                                        withAnimation(.easeInOut(duration: 0.15)) { filter = option }
                                    }
                                }
                            }
                        }
                        .padding(.top, 16)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("알림 종류")

                        ForEach(groups, id: \.day) { group in
                            Text(group.day)
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Color.secondaryText)
                                .padding(.horizontal, 4)
                                .padding(.top, 22)

                            VStack(spacing: 0) {
                                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                    row(item)
                                    if index < group.items.count - 1 {
                                        RowDivider()
                                    }
                                }
                            }
                            .surfaceCard()
                            .padding(.top, 8)
                        }

                        if visibleItems.isEmpty {
                            Text("이 종류의 알림은 아직 없어요")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Color.secondaryText)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .surfaceCard()
                                .padding(.top, 16)
                        }
                    }

                    if !history.items.isEmpty {
                        AdSlotView(placement: .inboxNative, isPro: storeService.isPro, onProTap: { showPaywall = true })
                            .padding(.top, 22)
                    }

                    NavigationLink {
                        MyAlertsView(viewModel: viewModel, onAddFromTimetable: onShowTimetable)
                    } label: {
                        HStack {
                            Text("예약한 버스 알림")
                                .font(AppTheme.Typography.rowBody.weight(.medium))
                                .foregroundStyle(AppTheme.Color.primaryText)
                            Spacer()
                            HStack(spacing: 6) {
                                Text("\(viewModel.alertCount)개")
                                    .font(.system(size: 15))
                                    .monospacedDigit()
                                    .foregroundStyle(AppTheme.Color.secondaryText)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.Color.tertiaryText)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .surfaceCard(interactive: true)
                    .padding(.top, 22)

                    Text("최근 30일 동안 받은 알림을 보여줘요.")
                        .font(AppTheme.Typography.footnote)
                        .foregroundStyle(AppTheme.Color.tertiaryText)
                        .padding(.horizontal, 4)
                        .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
            .softScrollEdge()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .legacyToolbarBackground(AppTheme.Color.screenBackground.opacity(0.95))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("모두 읽음") { history.markAllRead() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(history.unreadCount == 0 ? AppTheme.Color.tertiaryText : AppTheme.Color.primaryText)
                    .disabled(history.unreadCount == 0)
            }
        }
        .alertBusDetailSheet(item: $busDetail, viewModel: viewModel)
        .navigationDestination(isPresented: $showNoticeList) {
            NoticeListView(notices: viewModel.notices) { notice in
                viewModel.markNoticeRead(notice.id)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeService)
        }
        .sheet(item: $noticeToOpen) { notice in
            NavigationStack {
                NoticeDetailView(notice: notice)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("닫기") { noticeToOpen = nil }
                                .foregroundStyle(AppTheme.Color.primaryText)
                        }
                    }
            }
        }
    }

    // MARK: - 행

    private func row(_ item: AppNotification) -> some View {
        Button {
            open(item)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.kind.systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppTheme.Color.secondaryButton))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(item.kind.label)
                        Spacer(minLength: 0)
                        HStack(spacing: 6) {
                            Text(NotificationHistoryStore.timeLabel(for: item.receivedAt))
                            Circle()
                                .fill(item.isRead ? Color.clear : AppTheme.Color.accent)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .font(AppTheme.Typography.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.secondaryText)

                    Text(item.title)
                        .font(.system(size: 16, weight: item.isRead ? .medium : .bold))
                        .monospacedDigit()
                        .foregroundStyle(item.isRead ? AppTheme.Color.primaryText.opacity(0.83) : AppTheme.Color.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if !item.body.isEmpty {
                        Text(item.body)
                            .font(AppTheme.Typography.caption)
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.isRead ? "" : "읽지 않음, ")\(item.kind.label), \(item.title)")
    }

    private func open(_ item: AppNotification) {
        history.markRead(id: item.id)
        switch item.target {
        case .bus(let direction, let time):
            busDetail = viewModel.makeBusDetailInfo(for: time, direction: direction)
        case .notice(let id):
            if let notice = viewModel.notices.first(where: { $0.id == id }) {
                viewModel.markNoticeRead(id)
                noticeToOpen = notice
            } else {
                // 목록에서 내려간 공지: 공지 목록을 보여준다
                showNoticeList = true
            }
        case .timetable:
            onShowTimetable?()
        case nil:
            openWithoutTarget(item)
        }
    }

    /// 대상을 남기지 못한 예전 기록. 종류로 갈 곳을 정한다.
    private func openWithoutTarget(_ item: AppNotification) {
        switch item.kind {
        case .bus, .lastBus:
            guard !viewModel.currentTimes.isEmpty else { return }
            busDetail = viewModel.makeBusDetailInfo(for: viewModel.lastBusTime)
        case .notice:
            showNoticeList = true
        case .timetable:
            onShowTimetable?()
        }
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(AppTheme.Color.secondaryText)
            Text("아직 받은 알림이 없어요")
                .font(AppTheme.Typography.groupTitle)
                .foregroundStyle(AppTheme.Color.primaryText)
                .padding(.top, 6)
            Text("버스 출발 알림, 공지사항, 시간표 업데이트가 오면 여기에 모여요")
                .font(.system(size: 14))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.Color.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                onShowTimetable?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("시간표에서 버스 알림 추가")
                }
                .font(AppTheme.Typography.rowValue.weight(.semibold))
                .foregroundStyle(AppTheme.Color.primaryText)
                .padding(.horizontal, 20)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.Color.secondaryButton))
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
        }
        .padding(.top, 36)
        .padding(.bottom, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .surfaceCard()
    }
}
