//
//  UserJourneyView.swift
//  FreshpaintDemo
//
//  Created by Fernando Putallaz on 27/06/2025.
//

import SwiftUI
import Freshpaint

struct UserJourneyView: View {
    @State private var currentStep = 0
    @State private var userName = "Demo User"
    @State private var userEmail = "demo@freshpaint.io"
    @State private var isTrialActive = false
    @State private var debugLogs: [String] = []
    @State private var showingDebugView = false
    
    private let journeySteps = [
        "Anonymous Visitor",
        "Sign Up Interest", 
        "Account Creation",
        "Onboarding",
        "Active User",
        "Premium Upgrade",
        "Power User"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                journeyProgressView
                currentStepView
                actionButtonsView
                debugButton
            }
            .padding()
        }
        .navigationTitle("User Journey")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDebugView) {
            DebugLogView(logs: debugLogs)
        }
        .onAppear {
            trackScreenView("User Journey Flow")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Text("User Lifecycle Tracking")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Simulate a complete user journey from anonymous visitor to power user")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var journeyProgressView: some View {
        VStack(spacing: 16) {
            Text("Current Step: \(journeySteps[currentStep])")
                .font(.headline)
                .foregroundColor(.primary)
            
            ProgressView(value: Double(currentStep), total: Double(journeySteps.count - 1))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(height: 8)
            
            HStack {
                Text("Step \(currentStep + 1)")
                Spacer()
                Text("of \(journeySteps.count)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var currentStepView: some View {
        VStack(spacing: 16) {
            stepContentView
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    @ViewBuilder
    private var stepContentView: some View {
        switch currentStep {
        case 0:
            anonymousVisitorView
        case 1:
            signUpInterestView
        case 2:
            accountCreationView
        case 3:
            onboardingView
        case 4:
            activeUserView
        case 5:
            premiumUpgradeView
        case 6:
            powerUserView
        default:
            EmptyView()
        }
    }
    
    private var anonymousVisitorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Anonymous Visitor")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("User is browsing without identification. Track page views and interactions.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var signUpInterestView: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Sign Up Interest")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("User shows interest in signing up. Track CTA interactions and form engagement.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var accountCreationView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text("Account Creation")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Name:")
                    TextField("Enter name", text: $userName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                HStack {
                    Text("Email:")
                    TextField("Enter email", text: $userEmail)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            Text("User creates an account. This is where we identify the user and alias their anonymous activity.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var onboardingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 40))
                .foregroundColor(.purple)
            
            Text("Onboarding")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("User completes onboarding. Track completion rates and feature discovery.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var activeUserView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.mint)
            
            Text("Active User")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("User actively engages with the product. Track feature usage and engagement metrics.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var premiumUpgradeView: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            
            Text("Premium Upgrade")
                .font(.title3)
                .fontWeight(.semibold)
            
            Toggle("Trial Active", isOn: $isTrialActive)
                .toggleStyle(SwitchToggleStyle())
            
            Text("User upgrades to premium. Track conversion events and subscription metrics.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var powerUserView: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            Text("Power User")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("User becomes a power user. Track advanced feature usage and advocacy behaviors.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button("Previous Step") {
                    withAnimation {
                        currentStep -= 1
                    }
                    trackStepChange(direction: "backward")
                }
                .buttonStyle(.bordered)
            }
            
            Button("Execute Step") {
                executeCurrentStep()
            }
            .buttonStyle(.borderedProminent)
            
            if currentStep < journeySteps.count - 1 {
                Button("Next Step") {
                    withAnimation {
                        currentStep += 1
                    }
                    trackStepChange(direction: "forward")
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var debugButton: some View {
        Button("View Journey Logs (\(debugLogs.count))") {
            showingDebugView = true
        }
        .foregroundColor(.blue)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: 1)
        )
    }
    
    // MARK: - Journey Actions
    
    private func executeCurrentStep() {
        switch currentStep {
        case 0:
            executeAnonymousVisitor()
        case 1:
            executeSignUpInterest()
        case 2:
            executeAccountCreation()
        case 3:
            executeOnboarding()
        case 4:
            executeActiveUser()
        case 5:
            executePremiumUpgrade()
        case 6:
            executePowerUser()
        default:
            break
        }
    }
    
    private func executeAnonymousVisitor() {
        // Track anonymous page views
        let properties: [String: Any] = [
            "page": "landing_page",
            "source": "demo",
            "visitor_type": "anonymous"
        ]
        
        Freshpaint.shared().track("Page Viewed", properties: properties)
        Freshpaint.shared().screen("Landing Page", properties: ["visitor_status": "anonymous"])
        
        addDebugLog("🔍 Anonymous visitor tracked page view")
        addDebugLog("Properties: \(properties)")
    }
    
    private func executeSignUpInterest() {
        let properties: [String: Any] = [
            "cta_text": "Get Started Free",
            "cta_location": "hero_section",
            "interest_level": "high"
        ]
        
        Freshpaint.shared().track("CTA Clicked", properties: properties)
        Freshpaint.shared().screen("Sign Up Form", properties: ["funnel_step": "interest"])
        
        addDebugLog("👋 Sign up interest tracked")
        addDebugLog("Properties: \(properties)")
    }
    
    private func executeAccountCreation() {
        let userId = "user_\(UUID().uuidString.prefix(8))"
        
        // First, alias the anonymous user to the new user ID
        Freshpaint.shared().alias(userId)
        
        // Then identify with user traits
        let traits: [String: Any] = [
            "name": userName,
            "email": userEmail,
            "signup_date": ISO8601DateFormatter().string(from: Date()),
            "signup_method": "demo",
            "onboarding_completed": false
        ]
        
        Freshpaint.shared().identify(userId, traits: traits)
        
        // Track the account creation event
        let properties: [String: Any] = [
            "account_type": "freemium",
            "signup_source": "demo_flow",
            "trial_eligible": true
        ]
        
        Freshpaint.shared().track("Account Created", properties: properties)
        
        addDebugLog("🆕 Account created and user identified")
        addDebugLog("User ID: \(userId)")
        addDebugLog("Traits: \(traits)")
    }
    
    private func executeOnboarding() {
        let properties: [String: Any] = [
            "onboarding_step": "profile_setup",
            "completion_rate": 0.6,
            "time_spent_seconds": 120
        ]
        
        Freshpaint.shared().track("Onboarding Step Completed", properties: properties)
        
        // Update user traits
        let updatedTraits: [String: Any] = [
            "onboarding_completed": true,
            "onboarding_completion_date": ISO8601DateFormatter().string(from: Date())
        ]
        
        Freshpaint.shared().identify(nil, traits: updatedTraits)
        
        addDebugLog("🎓 Onboarding step completed")
        addDebugLog("Properties: \(properties)")
    }
    
    private func executeActiveUser() {
        let features = ["dashboard", "reports", "integrations", "alerts"]
        let randomFeature = features.randomElement() ?? "dashboard"
        
        let properties: [String: Any] = [
            "feature_name": randomFeature,
            "usage_frequency": "daily",
            "session_duration_minutes": Int.random(in: 5...45)
        ]
        
        Freshpaint.shared().track("Feature Used", properties: properties)
        
        // Track engagement
        let engagementProps: [String: Any] = [
            "engagement_score": Int.random(in: 7...10),
            "features_used_today": Int.random(in: 3...7)
        ]
        
        Freshpaint.shared().track("Daily Engagement", properties: engagementProps)
        
        addDebugLog("🏃‍♂️ Active user engagement tracked")
        addDebugLog("Feature used: \(randomFeature)")
    }
    
    private func executePremiumUpgrade() {
        let properties: [String: Any] = [
            "plan_name": "Premium",
            "billing_cycle": "monthly",
            "price": 29.99,
            "currency": "USD",
            "upgrade_source": "feature_limitation",
            "trial_active": isTrialActive
        ]
        
        Freshpaint.shared().track("Subscription Started", properties: properties)
        
        // Update user traits
        let premiumTraits: [String: Any] = [
            "plan": "premium",
            "subscription_status": "active",
            "upgrade_date": ISO8601DateFormatter().string(from: Date())
        ]
        
        Freshpaint.shared().identify(nil, traits: premiumTraits)
        
        addDebugLog("👑 Premium upgrade completed")
        addDebugLog("Properties: \(properties)")
    }
    
    private func executePowerUser() {
        let advancedFeatures = ["api_usage", "custom_dashboards", "advanced_integrations", "team_collaboration"]
        let randomFeature = advancedFeatures.randomElement() ?? "api_usage"
        
        let properties: [String: Any] = [
            "advanced_feature": randomFeature,
            "usage_level": "expert",
            "advocacy_score": Int.random(in: 8...10),
            "referrals_made": Int.random(in: 1...5)
        ]
        
        Freshpaint.shared().track("Advanced Feature Used", properties: properties)
        
        // Track advocacy behavior
        let advocacyProps: [String: Any] = [
            "nps_score": Int.random(in: 9...10),
            "referral_program_participant": true
        ]
        
        Freshpaint.shared().track("Customer Advocacy", properties: advocacyProps)
        
        addDebugLog("⭐ Power user behavior tracked")
        addDebugLog("Advanced feature: \(randomFeature)")
    }
    
    private func trackStepChange(direction: String) {
        let properties: [String: Any] = [
            "from_step": journeySteps[direction == "forward" ? currentStep - 1 : currentStep + 1],
            "to_step": journeySteps[currentStep],
            "direction": direction,
            "journey_progress": Double(currentStep) / Double(journeySteps.count - 1)
        ]
        
        Freshpaint.shared().track("Journey Step Changed", properties: properties)
        addDebugLog("🔄 Journey step changed: \(direction)")
    }
    
    private func trackScreenView(_ screenName: String) {
        Freshpaint.shared().screen(screenName, properties: ["journey_enabled": true])
        addDebugLog("📱 Screen view: \(screenName)")
    }
    
    private func addDebugLog(_ message: String) {
        let timestamp = DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"
        debugLogs.append(logMessage)
        
        if debugLogs.count > 50 {
            debugLogs.removeFirst()
        }
    }
}

#Preview {
    NavigationView {
        UserJourneyView()
    }
}