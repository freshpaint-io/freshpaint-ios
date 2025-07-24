//
//  SwiftUIScreenTrackingTests.swift
//  FreshpaintTests
//
//  Created by Freshpaint on 10/07/2025.
//

import Foundation
@testable import Freshpaint
import XCTest

#if os(iOS)
class SwiftUIScreenTrackingTests: XCTestCase {
    
    var passthrough: PassthroughMiddleware!
    var analytics: Freshpaint!
    
    override func setUp() {
        super.setUp()
        let config = FreshpaintConfiguration(writeKey: "test-key")
        config.recordScreenViews = true
        passthrough = PassthroughMiddleware()
        config.sourceMiddleware = [passthrough]
        analytics = Freshpaint(configuration: config)
    }
    
    override func tearDown() {
        super.tearDown()
        analytics.reset()
    }
    
    // MARK: - Firebase Analytics Properties Tests
    
    func testScreenEventIncludesFirebaseProperties() {
        analytics.screen("Test Screen")
        
        XCTAssertEqual(passthrough.lastContext?.eventType, EventType.screen)
        let screen = passthrough.lastContext?.payload as? ScreenPayload
        XCTAssertEqual(screen?.name, "Test Screen")
        
        // Check that properties include firebase fields
        XCTAssertNotNil(screen?.properties?["firebase_screen"])
        XCTAssertNotNil(screen?.properties?["firebase_screen_class"])
    }
    
    func testFirebaseScreenNameMapping() {
        analytics.screen("User Journey")
        
        let screen = passthrough.lastContext?.payload as? ScreenPayload
        XCTAssertEqual(screen?.properties?["firebase_screen"] as? String, "User Journey")
    }
    
    func testFirebaseScreenClassMapping() {
        analytics.screen("Core Features")
        
        let screen = passthrough.lastContext?.payload as? ScreenPayload
        XCTAssertEqual(screen?.properties?["firebase_screen_class"] as? String, "CoreFeaturesScreen")
    }
    
    func testFirebaseScreenClassWithSpaces() {
        analytics.screen("User Journey Tab")
        
        let screen = passthrough.lastContext?.payload as? ScreenPayload
        XCTAssertEqual(screen?.properties?["firebase_screen_class"] as? String, "UserJourneyTabScreen")
    }
    
    func testFirebaseScreenClassWithSpecialCharacters() {
        analytics.screen("Settings & Privacy")
        
        let screen = passthrough.lastContext?.payload as? ScreenPayload
        XCTAssertEqual(screen?.properties?["firebase_screen_class"] as? String, "SettingsPrivacyScreen")
    }
    
    func testFirebaseScreenClassWithSingleWord() {
        analytics.screen("Home")
        
        let screen = passthrough.lastContext?.payload as? ScreenPayload
        XCTAssertEqual(screen?.properties?["firebase_screen_class"] as? String, "HomeScreen")
    }
    
    func testFirebaseScreenClassWithEmptyString() {
        analytics.screen("")
        
        let screen = passthrough.lastContext?.payload as? ScreenPayload
        XCTAssertEqual(screen?.properties?["firebase_screen_class"] as? String, "UnknownScreen")
    }
    
    // MARK: - SwiftUI Screen Name Improvement Tests
    
    func testSwiftUIScreenNameImprovement() {
        let viewController = MockUIHostingController()
        viewController.title = "Settings"
        
        let improvedName = UIViewController.seg_improveScreenNameForSwiftUI(
            "_TtGC7SwiftUI19UIHostingController",
            fromViewController: viewController
        )
        
        XCTAssertEqual(improvedName, "Settings")
    }
    
    func testSwiftUIScreenNameWithNavigationTitle() {
        let viewController = MockUIHostingController()
        viewController.navigationItem.title = "Profile Settings"
        
        let improvedName = UIViewController.seg_improveScreenNameForSwiftUI(
            "_TtGC7SwiftUI19UIHostingController",
            fromViewController: viewController
        )
        
        XCTAssertEqual(improvedName, "Profile Settings")
    }
    
    func testSwiftUIScreenNameWithTabBarTitle() {
        let viewController = MockUIHostingController()
        viewController.tabBarItem = UITabBarItem(title: "Dashboard", image: nil, tag: 0)
        
        let improvedName = UIViewController.seg_improveScreenNameForSwiftUI(
            "_TtGC7SwiftUI19UIHostingController",
            fromViewController: viewController
        )
        
        XCTAssertEqual(improvedName, "Dashboard")
    }
    
    func testSwiftUIScreenNameFallback() {
        let viewController = MockUIHostingController()
        
        let improvedName = UIViewController.seg_improveScreenNameForSwiftUI(
            "_TtGC7SwiftUI19UIHostingController",
            fromViewController: viewController
        )
        
        XCTAssertEqual(improvedName, "SwiftUI Screen")
    }
    
    func testNonSwiftUIScreenNamePassthrough() {
        let viewController = UIViewController()
        
        let improvedName = UIViewController.seg_improveScreenNameForSwiftUI(
            "MyCustomViewController",
            fromViewController: viewController
        )
        
        XCTAssertEqual(improvedName, "MyCustomViewController")
    }
    
    // MARK: - Deduplication Tests
    
    func testScreenEventDeduplication() {
        let screenName = "Test Deduplication Screen"
        
        // Should allow first event
        let shouldTrack1 = UIViewController.seg_shouldTrackScreenEvent(screenName)
        XCTAssertTrue(shouldTrack1)
        
        // Should block immediate duplicate
        let shouldTrack2 = UIViewController.seg_shouldTrackScreenEvent(screenName)
        XCTAssertFalse(shouldTrack2)
        
        // Simulate time passing (> 500ms window)
        Thread.sleep(forTimeInterval: 0.6)
        
        // Should allow after timeout
        let shouldTrack3 = UIViewController.seg_shouldTrackScreenEvent(screenName)
        XCTAssertTrue(shouldTrack3)
    }
    
    func testDifferentScreenEventsAllowed() {
        let shouldTrack1 = UIViewController.seg_shouldTrackScreenEvent("Screen A")
        let shouldTrack2 = UIViewController.seg_shouldTrackScreenEvent("Screen B")
        
        XCTAssertTrue(shouldTrack1)
        XCTAssertTrue(shouldTrack2)
    }
}

// MARK: - Mock Classes

class MockUIHostingController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

#endif