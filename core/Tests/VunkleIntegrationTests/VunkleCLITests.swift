import XCTest

final class VunkleCLITests: XCTestCase {

    /// Set this env var to point at a real test video (e.g. secret-world.mp4)
    /// export VUNKLE_TEST_VIDEO=/path/to/video.mp4
    var testVideo: String {
        ProcessInfo.processInfo.environment["VUNKLE_TEST_VIDEO"] ?? ""
    }

    func run(_ args: [String]) throws -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["vunkle"] + args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(decoding: data, as: UTF8.self)
        return (p.terminationStatus, out)
    }

    func testHelp() throws {
        let (code, out) = try run(["--help"])
        XCTAssertEqual(code, 0)
        XCTAssertTrue(out.lowercased().contains("vunkle"))
    }

    func testFormatRoundTrip() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test.vunkle.txt")
        try "export:\n 1 2 3 4".write(to: tmp, atomically: true, encoding: .utf8)
        let (code, out) = try run(["format", tmp.path])
        XCTAssertEqual(code, 0)
        XCTAssertTrue(out.contains("export:"))
    }

    func testDetectGridIfVideoProvided() throws {
        guard !testVideo.isEmpty else { return }
        let (code, out) = try run(["detect-grid", testVideo, "--emit-vunkle"])
        XCTAssertEqual(code, 0)
        XCTAssertTrue(out.lowercased().contains("bpm"))
    }
}
