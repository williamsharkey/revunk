import XCTest
@testable import VunkleCore

final class VunkleTextParserTests: XCTestCase {
    func testBasicFileParsing() throws {
        let text = """
        video: test.mov
        downbeat: 00:00:01.500
        bpm: 120

        export:
          1  2  3  4
          5  6
        """

        let parser = VunkleTextParser()
        let file = try parser.parse(text)

        XCTAssertEqual(file.video, "test.mov")
        XCTAssertEqual(file.bpm, 120)
        XCTAssertEqual(file.exportBeats.map { $0.beat }, [1,2,3,4,5,6])
        XCTAssertEqual(file.downbeat?.seconds, 1.5, accuracy: 0.001)
    }

    func testAnchorsAndTempo() throws {
        let text = """
        downbeat: 0
        bpm: 100

        anchor:
          32 00:00:15.9

        tempo:
          33 90
        """

        let file = try VunkleTextParser().parse(text)

        XCTAssertEqual(file.anchors.count, 1)
        XCTAssertEqual(file.anchors.first?.index, 32)
        XCTAssertEqual(file.tempoChanges.first?.bpm, 90)
    }
}
