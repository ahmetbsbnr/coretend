// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@preconcurrency import UserNotifications
import Persistence
import DesignSystem
@testable import CoreTendApp

// MARK: - Fakes

private actor RecordingDelivery: NotificationDelivering {
    struct Posted: Sendable { let id: String; let title: String; let body: String; let route: String }
    private(set) var posts: [Posted] = []
    var status: UNAuthorizationStatus = .authorized

    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async -> UNAuthorizationStatus { status = .authorized; return status }
    func post(identifier: String, title: String, body: String, routeModule: String) async {
        posts.append(Posted(id: identifier, title: title, body: body, route: routeModule))
    }
    func setStatus(_ s: UNAuthorizationStatus) { status = s }
}

private func tempStore() throws -> Store {
    try Store(path: FileManager.default.temporaryDirectory
        .appendingPathComponent("notif-\(UUID().uuidString).sqlite").path)
}

private func prefs() -> NotificationPreferences {
    NotificationPreferences(defaults: UserDefaults(suiteName: "notif.test.\(UUID().uuidString)")!)
}

@Suite("NotificationPolicy — pure thresholds & rate limiting")
struct NotificationPolicyTests {
    @Test func lowDiskFloorIsFiveGigabytes() {
        #expect(NotificationPolicy.isLowDisk(freeBytes: 4_000_000_000))
        #expect(!NotificationPolicy.isLowDisk(freeBytes: 6_000_000_000))
    }

    @Test func reclaimableAndGrowthThresholds() {
        #expect(!NotificationPolicy.isMeaningfulReclaimable(500_000_000))
        #expect(NotificationPolicy.isMeaningfulReclaimable(2_000_000_000))
        #expect(!NotificationPolicy.isSignificantGrowth(1_000_000_000))
        #expect(NotificationPolicy.isSignificantGrowth(6_000_000_000))
    }

    @Test func rateLimitAllowsWhenNeverFiredOrLongAgoAndBlocksWhenRecent() {
        let now = Date()
        #expect(NotificationPolicy.rateLimitAllows(category: .lowDiskSpace, lastFired: nil, now: now))
        #expect(!NotificationPolicy.rateLimitAllows(category: .lowDiskSpace,
                                                    lastFired: now.addingTimeInterval(-3600), now: now))
        #expect(NotificationPolicy.rateLimitAllows(category: .lowDiskSpace,
                                                   lastFired: now.addingTimeInterval(-25 * 3600), now: now))
        #expect(NotificationPolicy.minimumInterval(for: .scanResults) == 12 * 3600)
    }
}

@Suite("NotificationService — delivery, permission, rate limiting, privacy")
@MainActor
struct NotificationServiceTests {
    @Test func nothingIsPostedWithoutPermission() async throws {
        let delivery = RecordingDelivery()
        await delivery.setStatus(.denied)
        let service = NotificationService(delivery: delivery, preferences: prefs(),
                                          store: try tempStore(), now: { Date() })
        await service.checkLowDiskSpace(freeBytes: 1_000_000_000)
        await service.reportScheduledScan(reclaimableBytes: 9_000_000_000, growthBytes: 9_000_000_000)
        #expect(await delivery.posts.isEmpty)
    }

    @Test func lowDiskPostsOnceThenIsRateLimitedForADay() async throws {
        let delivery = RecordingDelivery()
        var clock = Date()
        let service = NotificationService(delivery: delivery, preferences: prefs(),
                                          store: try tempStore(), now: { clock })
        await service.checkLowDiskSpace(freeBytes: 2_000_000_000)
        #expect(await delivery.posts.count == 1)
        // Same day: suppressed.
        clock = clock.addingTimeInterval(3600)
        await service.checkLowDiskSpace(freeBytes: 1_000_000_000)
        #expect(await delivery.posts.count == 1)
        // Next day: fires again.
        clock = clock.addingTimeInterval(25 * 3600)
        await service.checkLowDiskSpace(freeBytes: 1_000_000_000)
        #expect(await delivery.posts.count == 2)
    }

    @Test func lowDiskDoesNotFireWhenSpaceIsFine() async throws {
        let delivery = RecordingDelivery()
        let service = NotificationService(delivery: delivery, preferences: prefs(),
                                          store: try tempStore(), now: { Date() })
        await service.checkLowDiskSpace(freeBytes: 200_000_000_000)
        #expect(await delivery.posts.isEmpty)
    }

    @Test func aDisabledCategoryNeverPosts() async throws {
        let delivery = RecordingDelivery()
        let p = prefs()
        p.setEnabled(false, for: .lowDiskSpace)
        let service = NotificationService(delivery: delivery, preferences: p,
                                          store: try tempStore(), now: { Date() })
        await service.checkLowDiskSpace(freeBytes: 500_000_000)
        #expect(await delivery.posts.isEmpty)
    }

    @Test func scheduledScanBelowThresholdsPostsNothing() async throws {
        let delivery = RecordingDelivery()
        let service = NotificationService(delivery: delivery, preferences: prefs(),
                                          store: try tempStore(), now: { Date() })
        await service.reportScheduledScan(reclaimableBytes: 100_000_000, growthBytes: 1_000_000_000)
        #expect(await delivery.posts.isEmpty)
    }

    @Test func meaningfulReclaimablePostsOnceRoutedToStorage() async throws {
        let delivery = RecordingDelivery()
        let service = NotificationService(delivery: delivery, preferences: prefs(),
                                          store: try tempStore(), now: { Date() })
        await service.reportScheduledScan(reclaimableBytes: 8_400_000_000, growthBytes: nil)
        let posts = await delivery.posts
        #expect(posts.count == 1)
        #expect(posts.first?.route == ModuleID.cleanup.rawValue)
    }

    @Test func growthOnlyRoutesToTimeline() async throws {
        let delivery = RecordingDelivery()
        let service = NotificationService(delivery: delivery, preferences: prefs(),
                                          store: try tempStore(), now: { Date() })
        await service.reportScheduledScan(reclaimableBytes: 100_000_000, growthBytes: 9_000_000_000)
        let posts = await delivery.posts
        #expect(posts.count == 1)
        #expect(posts.first?.route == ModuleID.timeline.rawValue)
    }

    @Test func reclaimableAndGrowthAreCoalescedIntoASinglePost() async throws {
        let delivery = RecordingDelivery()
        let service = NotificationService(delivery: delivery, preferences: prefs(),
                                          store: try tempStore(), now: { Date() })
        await service.reportScheduledScan(reclaimableBytes: 8_000_000_000, growthBytes: 7_000_000_000)
        let posts = await delivery.posts
        #expect(posts.count == 1, "one coalesced notification, never two")
        let body = try #require(posts.first?.body)
        #expect(body.contains(L("notif.scan.reclaimable", mcFormatBytes(8_000_000_000))))
        #expect(body.contains(L("notif.scan.growth", mcFormatBytes(7_000_000_000))))
    }

    @Test func aSecondCompletionAlertIsSuppressedWithinTwelveHours() async throws {
        let delivery = RecordingDelivery()
        var clock = Date()
        let service = NotificationService(delivery: delivery, preferences: prefs(),
                                          store: try tempStore(), now: { clock })
        await service.reportScheduledScan(reclaimableBytes: 8_000_000_000, growthBytes: nil)
        clock = clock.addingTimeInterval(6 * 3600)
        await service.reportScheduledScan(reclaimableBytes: 8_000_000_000, growthBytes: nil)
        #expect(await delivery.posts.count == 1)
        clock = clock.addingTimeInterval(13 * 3600)
        await service.reportScheduledScan(reclaimableBytes: 8_000_000_000, growthBytes: nil)
        #expect(await delivery.posts.count == 2)
    }

    @Test func notificationContentNeverLeaksAPathNameOrLocation() async throws {
        let delivery = RecordingDelivery()
        var clock = Date()
        let service = NotificationService(delivery: delivery, preferences: prefs(),
                                          store: try tempStore(), now: { clock })
        await service.checkLowDiskSpace(freeBytes: 500_000_000)
        clock = clock.addingTimeInterval(25 * 3600)
        await service.reportScheduledScan(reclaimableBytes: 8_000_000_000, growthBytes: 7_000_000_000)
        for post in await delivery.posts {
            for field in [post.title, post.body] {
                #expect(!field.contains("/"))
                #expect(!field.contains(NSHomeDirectory()))
                #expect(!field.contains(NSUserName()))
                #expect(!field.lowercased().contains(".trash"))
            }
            #expect(ModuleID(rawValue: post.route) != nil, "route payload is a plain ModuleID rawValue")
        }
    }
}

@Suite("NotificationTapRouter — deep-link mapping")
struct NotificationTapRouterTests {
    @Test func routeKeyMapsToAModule() {
        #expect(NotificationTapRouter.module(from: ["route": "Cleanup"]) == .cleanup)
        #expect(NotificationTapRouter.module(from: ["route": "Timeline"]) == .timeline)
    }

    @Test func missingOrUnknownRouteIsNil() {
        #expect(NotificationTapRouter.module(from: [:]) == nil)
        #expect(NotificationTapRouter.module(from: ["route": "NotARealModule"]) == nil)
        #expect(NotificationTapRouter.module(from: ["route": 42]) == nil)
    }

    @Test func everyCategoryRoutesToARealModule() {
        for category in NotificationCategory.allCases {
            #expect(SidebarGroup.visibleModules.contains(category.routeModule))
        }
    }
}
