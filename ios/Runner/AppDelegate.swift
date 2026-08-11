// ─────────────────────────────────────────────────────────────────
// ADD THIS to your existing ios/Runner/AppDelegate.swift
// ─────────────────────────────────────────────────────────────────
//
// This does NOT replace your AppDelegate.swift — merge it into your
// existing application(_:didFinishLaunchingWithOptions:) method,
// alongside whatever GeneratedPluginRegistrant.register(...) and
// other setup you already have there.
//
// Purpose: exposes a method channel that lets Dart ask "is this
// device running a TestFlight/sandbox build?" by checking whether
// the on-device App Store receipt file is named "sandboxReceipt"
// (TestFlight/sandbox) vs the production receipt filename.

import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ── existing plugin registration — keep whatever you already have ──
    GeneratedPluginRegistrant.register(with: self)

    // ── ADD THIS BLOCK ──────────────────────────────────────────
    let controller = window?.rootViewController as! FlutterViewController
    let receiptChannel = FlutterMethodChannel(
        name: "com.geraldmiller.safeprep/receipt",
        binaryMessenger: controller.binaryMessenger
    )
    receiptChannel.setMethodCallHandler { (call, result) in
        if call.method == "isSandboxReceipt" {
            let receiptURL = Bundle.main.appStoreReceiptURL
            let isSandbox = receiptURL?.lastPathComponent == "sandboxReceipt"
            result(isSandbox)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    // ── END ADDED BLOCK ─────────────────────────────────────────

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}