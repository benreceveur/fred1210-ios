import XCTest
@testable import Fred1210

final class Fred1210Tests: XCTestCase {
    func testThemeExposesAllBrandColors() throws {
        // Smoke test: the theme tokens load without crashing.
        _ = Theme.primary
        _ = Theme.bgDark
        _ = Theme.textPrimary
        XCTAssertEqual(Theme.Spacing.lg, 16)
        XCTAssertEqual(Theme.Font.md, 15)
    }

    func testFredConfigFallsBackToDefaultHost() throws {
        // When the keychain has no stored host, hostURL should equal
        // the hard-coded Tailscale fallback.
        let config = FredConfig()
        XCTAssertEqual(
            config.hostURL.absoluteString,
            FredConfig.defaultHost,
            "FredConfig should default to the Tailscale host when keychain is empty"
        )
    }
}
