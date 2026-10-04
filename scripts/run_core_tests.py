#!/usr/bin/env python3
"""Run unchanged Foundation-only production code and regression tests on macOS."""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [
    "Services/DateService.swift",
    "Services/TimetableTimeline.swift",
    "Models/TimetableData.swift",
    "Models/TimetableRevision.swift",
]
TESTS = ["DateServiceTests.swift", "TimetableDataTests.swift", "TimetableTimelineTests.swift"]

with tempfile.TemporaryDirectory(prefix="localbus-core-tests-") as directory:
    package = Path(directory)
    sources = package / "Sources/JangyuBus"
    tests = package / "Tests/CoreTests"
    sources.mkdir(parents=True)
    tests.mkdir(parents=True)
    for source in SOURCES:
        shutil.copy2(ROOT / "LocalBusApp/LocalBusApp" / source, sources)
    for test in TESTS:
        shutil.copy2(ROOT / "LocalBusApp/LocalBusAppTests" / test, tests)
    shutil.copy2(ROOT / "CoreTests/HolidayFixtureTests.swift", tests)
    fixture = ROOT / "LocalBusApp/LocalBusApp/Resources/timetable.json"
    shutil.copy2(fixture, tests)
    # 기존 #filePath 기반 테스트가 기대하는 상대 경로도 그대로 제공합니다.
    legacy_resources = package / "Tests/LocalBusApp/Resources"
    legacy_resources.mkdir(parents=True)
    shutil.copy2(fixture, legacy_resources)
    (package / "Package.swift").write_text("""// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "LocalBusCoreRegression",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "JangyuBus"),
        .testTarget(name: "CoreTests", dependencies: ["JangyuBus"], resources: [.copy("timetable.json")])
    ],
    swiftLanguageModes: [.v5]
)
""")
    result = subprocess.run(["swift", "test", "--package-path", str(package)])
    raise SystemExit(result.returncode)
