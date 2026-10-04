import Foundation
import Testing
import MessageUI
@testable import JangyuBus

@Suite("설정 회귀")
struct SettingsRegressionTests {
    @Test func 메일실패와_임시저장은_완료로안내하지않음() {
        #expect(MailResultNotice.make(result: .failed, error: nil)?.title == "메일 전송 실패")
        #expect(MailResultNotice.make(result: .saved, error: nil)?.title == "임시 저장됨")
        #expect(MailResultNotice.make(result: .cancelled, error: nil) == nil)
    }

    @Test func 같은버전내용수정감지_이전버전차단() throws {
        let current = updateFixture(version: 3, time: "08:10")
        #expect(try updateFixture(version: 3, time: "08:20").isUpdate(comparedTo: current))
        #expect(try !updateFixture(version: 2, time: "08:20").isUpdate(comparedTo: current))
        #expect(try !current.isUpdate(comparedTo: current))
    }
}

private func updateFixture(version: Int, time: String) -> TimetableData {
    TimetableData(meta: Meta(version: version, updatedAt: "2026-09-12", noticeMessage: nil, contactEmail: "test@example.com"),
                  holidays: [], timetable: Timetable(weekday: [time], weekend: [time]))
}
