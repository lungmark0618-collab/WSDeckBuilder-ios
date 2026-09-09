import XCTest
import SwiftUI
@testable import WSDeckBuilder

final class AppearancePaletteTests: XCTestCase {
    func testCustomColorRoundTripsWithoutLosingChannels() {
        for hex in ["000000", "FFFFFF", "E8E4DC", "123456", "FF00AA"] {
            XCTAssertEqual(UIColor(rgbHex: hex).rgbHex, hex)
        }
        XCTAssertEqual(UIColor(rgbHex: "invalid").rgbHex, "E8E4DC")
    }

    func testBackgroundSelectsLegibleBlackOrWhiteText() {
        for hex in ["000000", "FFFFFF", "E8E4DC", "FF0000", "00FF00", "0000FF", "777777"] {
            let luminance = UIColor(rgbHex: hex).relativeLuminance
            let contrast = luminance > 0.179 ? (luminance + 0.05) / 0.05 : 1.05 / (luminance + 0.05)
            XCTAssertGreaterThanOrEqual(contrast, 4.5, hex)
        }
    }

    func testSystemPanelsFollowTraitsAndCustomBackgroundKeepsSelectedColor() {
        let system = AppSurface(style: .system)
        let light = UIColor(system.panel).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = UIColor(system.panel).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        XCTAssertGreaterThan(light.relativeLuminance, dark.relativeLuminance)
        let custom = AppSurface(style: .custom, customHex: "123456")
        XCTAssertEqual(UIColor(custom.background).rgbHex, "123456")
    }
}
