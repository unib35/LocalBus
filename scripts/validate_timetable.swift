import Foundation

@main
struct ValidateTimetable {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw ValidationFailure.usage
        }
        let bytes = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let timetable = try TimetableData.validatedDecode(bytes)
        try timetable.validate(requireRoutes: true)
        print("시간표 검증 통과: v\(timetable.meta.version), \(timetable.routes?.count ?? 0)방향, 공휴일 \(timetable.holidays.count)개")
    }
    enum ValidationFailure: Error { case usage }
}
