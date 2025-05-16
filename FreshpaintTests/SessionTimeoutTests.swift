//
//  SessionTimeoutTests.swift
//  Freshpaint
//
//  Created by Miguel Vargas on 5/16/25.
//  Copyright © 2025 Freshpaint. All rights reserved.
//

import XCTest
@testable import Freshpaint 

/// Verifies that a new configuration picks up the default timeout (1800 s).
final class SessionTimeoutTests: XCTestCase {

    /// The configuration should default to 1 800 s (30 min)
    func testDefaultSessionTimeout() {
        let cfg = FreshpaintConfiguration(writeKey: "dummy-key")
        XCTAssertEqual(cfg.sessionTimeout, 1_800,
                       "sessionTimeout should default to 1800 s (kDefaultSessionTimeout)")
    }

    /// If the user sets a custom timeout, that value must be kept.
    func testCustomSessionTimeoutOverridesDefault() {
        let cfg = FreshpaintConfiguration(writeKey: "dummy-key")
        cfg.sessionTimeout = 3_600   // 60 min
        XCTAssertEqual(cfg.sessionTimeout, 3_600,
                       "sessionTimeout should reflect the user-supplied value")
    }
}
