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
        /// 보조 텍스트. 다크 #A3A3A3 on #141414 = 7.3:1, 라이트 #525252 on #FFFFFF = 7.8:1.
        static let secondaryText = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.64, alpha: 1)         // #A3A3A3
                : UIColor(white: 0.322, alpha: 1)        // #525252
        })
        /// 3차 텍스트(각주·캡션). 다크 #8A8A8A on #141414 = 5.3:1, 라이트 #616161 on #F5F5F5 = 5.7:1.
        static let tertiaryText = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.541, alpha: 1)        // #8A8A8A
                : UIColor(white: 0.38, alpha: 1)         // #616161
        })

        // ── 서피스 (테두리 없는 평면 컨테이너) ─────────────────────
        /// 히어로·그룹 리스트 등 화면 배경 위에 놓이는 기본 서피스.
        static let surface = cardBackground
        /// 서피스 안의 한 단계 더 올라온 요소 (칩, 인라인 카드).
        static let surfaceSecondary = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.11,  alpha: 1)        // #1C1C1C
                : UIColor(white: 0.92,  alpha: 1)        // #EBEBEB
        })
        /// 보조 버튼·선택 안 된 칩 배경.
        static let secondaryButton = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.15,  alpha: 1)        // #262626
                : UIColor(white: 0.92,  alpha: 1)        // #EBEBEB
        })
        /// 시트 안 타일·카드. 시트 바탕(다크 #141414 / 라이트 #F5F5F5) 위에 놓인다.
        static let sheetTile = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.11,  alpha: 1)        // #1C1C1C
                : UIColor(white: 1,     alpha: 1)        // #FFFFFF
        })
        /// 서피스 안 행 사이 구분선.
        static let divider = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.133, alpha: 1)        // #222222
                : UIColor(white: 0.863, alpha: 1)        // #DCDCDC
        })

        // ── 강조색 (앱 전체에서 하나) ─────────────────────────────
        /// "지금 탈 버스" 신호에만 쓰는 단일 강조색. 다른 용도(장식·경고)에는 쓰지 않는다.
        /// 다크 #4ADE80 위 검정 = 12:1, 라이트 #166534 위 흰색 = 7.1:1.
        static let accent = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 74/255,  green: 222/255, blue: 128/255, alpha: 1)
                : UIColor(red: 22/255,  green: 101/255, blue: 52/255,  alpha: 1)
        })
        /// 기본 버튼을 누르는 동안의 배경 (다크 #3CC46E / 라이트 #14532D).
        static let accentPressed = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 60/255,  green: 196/255, blue: 110/255, alpha: 1)
                : UIColor(red: 20/255,  green: 83/255,  blue: 45/255,  alpha: 1)
        })
        /// accent 배경 위 텍스트 색.
        static let accentForeground = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark ? .black : .white
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
        /// 심야 요금에만 쓰는 색. 다크 #FB923C, 라이트 #C2410C.
        static let nightFare = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 251/255, green: 146/255, blue: 60/255, alpha: 1)
                : UIColor(red: 194/255, green: 65/255,  blue: 12/255, alpha: 1)
        })
        /// 문제 상황 안내(오프라인·확인 실패·운휴). 다크 #FBBF24, 라이트 #92400E.
        static let warning = SwiftUI.Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 251/255, green: 191/255, blue: 36/255, alpha: 1)
                : UIColor(red: 146/255, green: 64/255,  blue: 14/255, alpha: 1)
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

        // ── 개선안 스케일 (디자인 캔버스 기준) ───────────────────
        /// 화면 큰 제목 ("장유 → 사상", "설정")
        static let screenTitle      = Font.system(size: 32, weight: .heavy)
        /// 시트·보조 화면 제목
        static let sheetTitle       = Font.system(size: 22, weight: .heavy)
        /// 큰 제목 아래 한 줄 메타 ("장유 터미널 출발 · 26분 소요 · 2,500원")
        static let screenSubtitle   = Font.system(size: 13, weight: .medium)
        /// 섹션 제목 ("이어지는 버스")
        static let groupTitle       = Font.system(size: 17, weight: .bold)
        /// 히어로 남은 시간 숫자
        static let heroNumber       = Font.system(size: 76, weight: .heavy, design: .rounded)
        /// 출발 → 약 도착 큰 시각 쌍 (홈 히어로, 버스 상세 헤더)
        static let etaTime          = Font.system(size: 44, weight: .heavy, design: .rounded)
        /// 히어로 단위 ("분 후")
        static let heroUnitLabel    = Font.system(size: 22, weight: .bold)
        /// 리스트 행 시각
        static let rowTime          = Font.system(size: 17, weight: .semibold)
        /// 리스트 행 제목
        static let rowTitle         = Font.system(size: 16, weight: .semibold)
        /// 리스트 행 본문
        static let rowBody          = Font.system(size: 16, weight: .regular)
        /// 리스트 행 보조 (오른쪽 "27분 후")
        static let rowValue         = Font.system(size: 15, weight: .medium)
        /// 캡션 (칩, 설명)
        static let caption          = Font.system(size: 13, weight: .medium)
        /// 각주 (푸터, 범례)
        static let footnote         = Font.system(size: 12, weight: .medium)
        /// 버튼 라벨
        static let buttonLabel      = Font.system(size: 15, weight: .semibold)
        /// 기본 버튼 라벨
        static let buttonLabelStrong = Font.system(size: 16, weight: .bold)
        /// 시간표 그리드 셀
        static let gridCell         = Font.system(size: 16, weight: .semibold)
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
        /// 16pt — 그룹 리스트 서피스
        static let surface: CGFloat = 16
        /// 14pt — 기본 버튼
        static let primaryButton: CGFloat = 14
        /// 12pt — 보조 버튼
        static let secondaryButton: CGFloat = 12
        /// 10pt — 시간표 그리드 셀
        static let gridCell: CGFloat = 10
        /// 22pt — 칩·필 버튼 (높이 44 기준 완전한 캡슐)
        static let pill: CGFloat    = 22
    }
}

// MARK: - Backwards Compatibility
// 기존 코드가 그대로 컴파일되도록 typealias를 제공한다.
// 새 코드는 AppTheme.Color / AppTheme.Typography 를 직접 사용할 것.

typealias HomeDashboardTheme = AppTheme.Color
typealias HomeDashboardTypography = AppTheme.Typography
