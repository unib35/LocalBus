import SwiftUI
import UIKit

// MARK: - AppTheme
// 앱 전체 디자인 토큰의 단일 진실 공급원(Single Source of Truth).
// 색상, 타이포그래피, 간격, 모서리 반지름을 중앙에서 관리한다.
//
// 사용법:
//   AppTheme.Color.primaryBlue
//   AppTheme.Typography.heroValue
//   AppTheme.Spacing.card
//   AppTheme.Radius.card

enum AppTheme {

    // MARK: - Color

    enum Color {
        // ── 배경 ──────────────────────────────────────────────────
        static let screenBackground = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0,     alpha: 1)        // #000000
                : UIColor(white: 0.96,  alpha: 1)        // #F5F5F5
        })
        static let cardBackground = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.08,  alpha: 1)        // #141414
                : UIColor(white: 1,     alpha: 1)        // #FFFFFF
        })
        static let listCardBackground = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.11,  alpha: 1)        // #1C1C1C
                : UIColor(white: 1,     alpha: 1)        // #FFFFFF
        })
        static let sheetBackground = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.08,  alpha: 1)        // #141414
                : UIColor(white: 0.96,  alpha: 1)        // #F5F5F5
        })
        static let noteBackground = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.11,  alpha: 1)        // #1C1C1C
                : UIColor(white: 0.94,  alpha: 1)        // #F0F0F0
        })
        static let segmentBackground = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.10,  alpha: 1)        // #1A1A1A
                : UIColor(white: 0.92,  alpha: 1)        // #EBEBEB
        })
        static let iconBackground = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.17,  alpha: 1)        // #2B2B2B
                : UIColor(white: 0.94,  alpha: 1)        // #F0F0F0
        })
        static let chipBackground = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.17,  alpha: 1)        // #2B2B2B
                : UIColor(white: 0.92,  alpha: 1)        // #EBEBEB
        })

        // ── 텍스트 ────────────────────────────────────────────────
        static let primaryText = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? .white
                : UIColor(white: 0.05, alpha: 1)         // #0D0D0D
        })
        static let secondaryText = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.54, alpha: 1)         // #8A8A8A
                : UIColor(white: 0.40, alpha: 1)         // #666666
        })
        static let tertiaryText = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.33, alpha: 1)         // #555555 — ~6.5:1 WCAG AA
                : UIColor(white: 0.60, alpha: 1)         // #999999
        })

        // ── 히어로 카드 (항상 어두운 배경 — 라이트/다크 모두 동일) ──
        static let heroStart = SwiftUI.Color(UIColor { _ in
            UIColor(white: 0.10, alpha: 1)               // #1A1A1A
        })
        static let heroEnd = SwiftUI.Color(UIColor { _ in
            UIColor(white: 0.04, alpha: 1)               // #0A0A0A
        })
        static let heroOverlay = SwiftUI.Color.white.opacity(0.04)
        /// 히어로 카드는 항상 어두운 배경이므로 텍스트는 항상 흰색.
        static let heroText = SwiftUI.Color.white

        // ── 구분선 ────────────────────────────────────────────────
        static let border = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.18,  alpha: 1)        // #2E2E2E
                : UIColor(white: 0.88,  alpha: 1)        // #E0E0E0
        })
        static let listDivider = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.18,  alpha: 1)        // #2E2E2E
                : UIColor(white: 0.91,  alpha: 1)        // #E8E8E8
        })

        // ── 인터랙션 / 상태 ───────────────────────────────────────
        /// 선택·버튼·토글 등 주요 인터랙션 색상.
        /// 다크: 밝은 회색(#C8C8C8) — 순수 흰색은 토글 thumb과 구분 불가.
        /// 라이트: 어두운 회색(#2A2A2A) — 버튼·토글에 충분한 대비 확보.
        static let primaryBlue = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.78,  alpha: 1)        // #C8C8C8
                : UIColor(white: 0.16,  alpha: 1)        // #2A2A2A
        })
        /// primaryBlue 배경 위 텍스트 색상 — 항상 primaryBlue의 반대 명도.
        /// 다크: 검정(버튼 배경이 밝으므로), 라이트: 흰색(버튼 배경이 어두우므로).
        static let primaryForeground = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? .black
                : .white
        })
        /// 출발 정류장·완료 상태 강조색. 정보 전달 목적으로 유지.
        static let departureGreen = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 74/255,  green: 222/255, blue: 128/255, alpha: 1)
                : UIColor(red: 22/255,  green: 163/255, blue: 74/255,  alpha: 1)
        })
        static let success = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 16/255,  green: 185/255, blue: 129/255, alpha: 1)
                : UIColor(red: 5/255,   green: 150/255, blue: 105/255, alpha: 1)
        })
        /// 심야 버스·요금 강조색. 정보 전달 목적으로 유지.
        static let nightFare = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 251/255, green: 146/255, blue: 60/255, alpha: 1)
                : UIColor(red: 234/255, green: 88/255,  blue: 12/255, alpha: 1)
        })
        /// 삭제·오류 등 위험 동작에 사용.
        static let destructive = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 248/255, green: 113/255, blue: 113/255, alpha: 1)
                : UIColor(red: 220/255, green: 38/255,  blue: 38/255, alpha: 1)
        })

        // ── 시간표 전용 ───────────────────────────────────────────
        static let timetablePickerBackground  = segmentBackground
        static let timetablePickerBorder      = border
        static let timetablePickerSelected    = chipBackground
        static let timetableMutedText         = tertiaryText
        static let timetableSecondaryText     = secondaryText
        /// "NEXT" 배지 텍스트 — iconBackground 위에 표시되므로 모드에 맞게 반전.
        static let timetableNextBadge = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? .white
                : UIColor(white: 0.05, alpha: 1)         // #0D0D0D
        })
    }

    // MARK: - Typography

    enum Typography {
        // 헤더 / 세그먼트
        static let headerLabel      = Font.system(size: 14, weight: .medium)
        static let segmentSelected  = Font.system(size: 14, weight: .bold)
        static let segmentDefault   = Font.system(size: 14, weight: .medium)
        // 히어로 카드
        static let heroEyebrow      = Font.system(size: 12, weight: .medium)
        static let heroValue        = Font.system(size: 72, weight: .black, design: .rounded)
        static let heroUnit         = Font.system(size: 24, weight: .bold)
        static let heroDescription  = Font.system(size: 14, weight: .medium)
        static let heroMetaLabel    = Font.system(size: 11, weight: .bold)
        static let heroMetaValue    = Font.system(size: 20, weight: .bold, design: .monospaced)
        static let heroMetaSuffix   = Font.system(size: 12, weight: .medium)
        // 섹션
        static let sectionTitle     = Font.system(size: 20, weight: .black, design: .rounded)
        static let sectionBadge     = Font.system(size: 11, weight: .bold)
        // 버스 시간
        static let busTime          = Font.system(size: 18, weight: .bold, design: .monospaced)
        static let busRelativeStrong = Font.system(size: 14, weight: .bold)
        static let busRelativeMuted  = Font.system(size: 14, weight: .medium)
        static let busArrival       = Font.system(size: 12, weight: .medium)
        // 기타
        static let statusChip       = Font.system(size: 12, weight: .medium)
        static let noticeTitle      = Font.system(size: 14, weight: .bold)
        static let noticeBody       = Font.system(size: 12, weight: .medium)
    }

    // MARK: - Spacing
    // 카드·컴포넌트 패딩에 사용. 세부 레이아웃 조정값은 각 뷰에서 직접 지정.

    enum Spacing {
        /// 8pt — 아이콘·배지 등 소형 요소 내부 패딩
        static let xs: CGFloat = 8
        /// 12pt — 소형 카드 내부 패딩
        static let sm: CGFloat = 12
        /// 16pt — 일반 카드 패딩
        static let md: CGFloat = 16
        /// 20pt — 바텀시트·디테일 뷰 수평 여백
        static let lg: CGFloat = 20
        /// 24pt — 히어로 카드·주요 섹션 수평 여백
        static let xl: CGFloat = 24
    }

    // MARK: - Layout
    // VStack / HStack spacing 및 섹션 간격에 사용.

    enum Layout {
        // ── Stack 간격 ────────────────────────────────────────────
        /// 4pt — 제목+서브타이틀 등 밀착 배치
        static let stackTight: CGFloat  = 4
        /// 8pt — 같은 그룹 내 항목 간격
        static let stackSmall: CGFloat  = 8
        /// 12pt — 관련 항목 간격
        static let stackMedium: CGFloat = 12
        /// 16pt — 카드 내부 섹션 구분
        static let stackLarge: CGFloat  = 16
        /// 24pt — 화면 레벨 섹션 간격
        static let sectionGap: CGFloat  = 24

        // ── 줄간격 (lineSpacing) ──────────────────────────────────
        /// 3pt — 짧은 설명·힌트 텍스트
        static let lineSpacingTight: CGFloat = 3
        /// 5pt — 일반 본문
        static let lineSpacingBody: CGFloat  = 5
        /// 6pt — 여유 있는 본문 (공지·상세 설명)
        static let lineSpacingLoose: CGFloat = 6

        // ── 자간 (tracking) ───────────────────────────────────────
        /// -1pt — 큰 숫자(히어로 값, 시간) — 시각적 밀도 증가
        static let trackingTight: CGFloat    = -1
        /// 0.5pt — 일반 레이블·캡션
        static let trackingLabel: CGFloat    = 0.5
        /// 1.0pt — Eyebrow / 상태 칩 등 강조 레이블
        static let trackingEyebrow: CGFloat  = 1.0
    }

    // MARK: - Radius
    // RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)

    enum Radius {
        /// 4pt — 인라인 배지 (심야, 상태 뱃지)
        static let badge: CGFloat   = 4
        /// 8pt — 버튼, 소형 입력 요소
        static let button: CGFloat  = 8
        /// 10pt — 세그먼트 컨트롤
        static let segment: CGFloat = 10
        /// 12pt — 일반 카드
        static let card: CGFloat    = 12
        /// 14pt — 버스 카드 (BusCard)
        static let busCard: CGFloat = 14
        /// 20pt — 히어로 카드
        static let hero: CGFloat    = 20
    }
}

// MARK: - Backwards Compatibility
// 기존 코드가 그대로 컴파일되도록 typealias를 제공한다.
// 새 코드는 AppTheme.Color / AppTheme.Typography 를 직접 사용할 것.

typealias HomeDashboardTheme = AppTheme.Color
typealias HomeDashboardTypography = AppTheme.Typography
