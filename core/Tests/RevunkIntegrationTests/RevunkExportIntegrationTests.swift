import Foundation
#if canImport(XCTest)
import XCTest
#endif

final class RevunkExportIntegrationTests: XCTestCase {

    var testVideo: String {
        ProcessInfo.processInfo.environment["REVUNK_TEST_VIDEO"] ?? ""
    }

    func run(_ args: [String]) throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["revunk"] + args
        try p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }

    func testExportProducesOutput() throws {
        guard !testVideo.isEmpty else {
            throw XCTSkip("REVUNK_TEST_VIDEO not set")
        }

        let tmp = FileManager.default.temporaryDirectory
        let vunk = tmp.appendingPathComponent("test-export.revunk.txt")
        let out = tmp.appendingPathComponent("test-export.revunk.out.mp4")

        let text = """
        video: \(testVideo)
        downbeat: 0
        bpm: 120

        export:
          1 2 3 4
        """
        try text.write(to: vunk, atomically: true, encoding: .utf8)

        _ = try run(["export", vunk.path])

        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
    }
}
