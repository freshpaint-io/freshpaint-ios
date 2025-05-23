//
//  SessionIdInjectionTests.swift
//  Freshpaint
//
//  Created by Miguel Vargas on 5/16/25.
//  Copyright © 2025 Freshpaint. All rights reserved.
//
//  Tests
//  -------
//  1. Ensure the SDK injects a non-empty `$session_id` inside the
//     `properties` dictionary before an event leaves the queue.
//  2. Verify that a NEW `$session_id` is issued once the configured
//     `sessionTimeout` expires.
//  3. Confirm that, if a second event happens *within* the timeout
//     window, the original `$session_id` is reused (and other keys are
//     left intact).
//

import Freshpaint
import XCTest

class SessionIdInjectionTests: XCTestCase {

    var passthrough: PassthroughMiddleware!
    var analytics:   Freshpaint!
    var configuration: FreshpaintConfiguration!

    override func setUp() {
        super.setUp()

        configuration = FreshpaintConfiguration(writeKey: "3VxTfPsVOoEOSbbzzbFqVNcYMNu2vjnr")
        configuration.flushAt       = 1    // flush immediately after 1 event
        configuration.flushInterval = 0    // disable timer-based flush
        configuration.sessionTimeout = 1   // 1-second timeout for tests

        passthrough = PassthroughMiddleware()
        configuration.sourceMiddleware = [passthrough]

        analytics = Freshpaint(configuration: configuration)
    }

    override func tearDown() {
        analytics.reset()
        super.tearDown()
    }
    
    /// Asserts that the *queued* payload contains a non-empty `$session_id`.
    func testSessionIdIsInjectedInQueue() {
        let exp = expectation(description: "$session_id present after queue")
        
        let cfg = FreshpaintConfiguration(writeKey: "QUI5ydwIGeFFTa1IvCBUhxL9PyW5B0jE")
        cfg.flushAt       = 1         
        cfg.flushInterval = 0
        cfg.experimental.rawFreshpaintModificationBlock = { event in
            if
                let props = event["properties"] as? [String: Any],
                let sid   = props["$session_id"] as? String,
                !sid.isEmpty
            {
                exp.fulfill()
            }
            return event
        }
        
        let analytics = Freshpaint(configuration: cfg)
        analytics.track("session id test")
        analytics.flush()               
        
        wait(for: [exp], timeout: 3.0)
    }

    /// Sends two events separated by *more* than `sessionTimeout`.
    /// Expects a different `$session_id` on the second event.
    func testSessionIdRenewsAfterTimeout() {
        let exp = expectation(description: "second event carries new $session_id")
        var firstSessionId: String?

        configuration.experimental.rawFreshpaintModificationBlock = { event in
            guard
                let props = event["properties"] as? [String: Any],
                let sid   = props["$session_id"] as? String
            else { return event }

            if firstSessionId == nil {
                firstSessionId = sid // captured on first event
            } else if sid != firstSessionId {    
                exp.fulfill() // different → passes
            }
            return event
        }

        // First event
        analytics.track("first event")
        analytics.flush()

        // Second event after the 1-second timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.analytics.track("second event after timeout")
            self.analytics.flush()
        }

        wait(for: [exp], timeout: 3.0)
    }

    /// Sends two events *within* the same `sessionTimeout` window.
    /// Expects both to share the SAME `$session_id`.
    func testSessionIdPersistsWithinTimeout() {
        // 1 s timeout: we send the second event at 0.3 s.
        configuration.sessionTimeout = 10

        let exp = expectation(description: "second event keeps same $session_id")

        var firstSessionId: String?

        configuration.experimental.rawFreshpaintModificationBlock = { event in
            guard
                let props = event["properties"] as? [String: Any],
                let sid   = props["$session_id"] as? String
            else { return event }

            if firstSessionId == nil {
                firstSessionId = sid                   // captured on first event
            } else if sid == firstSessionId {          // identical → passes
                exp.fulfill()
            }
            return event
        }

        // First event
        analytics.track("first event within timeout")
        analytics.flush()

        // Second event 0.3 s later (well inside the 1-second timeout)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.analytics.track("second event within timeout")
            self.analytics.flush()
        }

        wait(for: [exp], timeout: 2.0)
    }

    /// Verifies the `$is_first_event_in_session` flag behavior:
    /// - `true` for the very first event ever or after the timeout expires.
    /// - `false` for intermediate events within the timeout period.
    func testIsFirstEventInSessionFlagBehavior() {
        let expectations = [
            expectation(description: "First event → true"),
            expectation(description: "Second event → false"),
            expectation(description: "Third event → true after timeout")
        ]

        let expectedFlags = [ true, false, true ]
        
        var eventIndex = 0

        configuration.experimental.rawFreshpaintModificationBlock = { event in
            guard
                let props   = event["properties"] as? [String: Any],
                let isFirstEventInSession = props["$is_first_event_in_session"] as? Bool
            else { return event }

            // Check against expectedFlags[eventIndex]
            if eventIndex < expectedFlags.count, isFirstEventInSession == expectedFlags[eventIndex] {
                expectations[eventIndex].fulfill()
            }
            
            eventIndex += 1
            return event
        }

        // First event
        analytics.track("first for flag");   
        analytics.flush()
        
        // Second event
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.analytics.track("second within timeout"); 
            self.analytics.flush();
        }

        // Third event
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.analytics.track("third after timeout"); 
            self.analytics.flush();
        }

        wait(for: expectations, timeout: 5.0)
    }

}
