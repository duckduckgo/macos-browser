import ProjectDescription

/// Project helpers are functions that simplify the way you define your project.
/// Share code to create targets, settings, dependencies,
/// Create your own conventions, e.g: a func that makes sure all shared targets are "static frameworks"
/// See https://docs.tuist.io/guides/helpers/

extension Project {
    /// Helper function to create the Project for this ExampleApp
    public static func app(name: String, platform: Platform, additionalTargets: [String]) -> Project {
        let targets = makeAppTargets(name: name,
                                     platform: platform,
                                     dependencies: additionalTargets.map { TargetDependency.target(name: $0) })
        return Project(name: name,
                       organizationName: "DuckDuckGo",
                       packages: [
                        .remote(url: "https://github.com/duckduckgo/TrackerRadarKit.git", requirement: .exact("1.0.3")),
                        .remote(url: "https://github.com/airbnb/lottie-ios", requirement: .upToNextMajor(from: "3.3.0")),
                        .remote(url: "https://github.com/gumob/PunycodeSwift.git", requirement: .upToNextMajor(from: "2.1.0")),
                        .remote(url: "https://github.com/AliSoftware/OHHTTPStubs.git", requirement: .upToNextMajor(from: "9.1.0")),
                        .remote(url: "https://github.com/sparkle-project/Sparkle.git", requirement: .exact("1.27.1")),
                        .remote(url: "https://github.com/duckduckgo/BrowserServicesKit", requirement: .upToNextMajor(from: "11.2.2"))
                       ],
                       targets: targets)
    }

    // MARK: - Private

    /// Helper function to create the application target and the unit test target.
    private static func makeAppTargets(name: String, platform: Platform, dependencies: [TargetDependency]) -> [Target] {
        let platform: Platform = platform
        let infoPlist: [String: InfoPlist.Value] = [
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "NSMainStoryboardFile": "MainMenu",
            "NSAppTransportSecurity": [
                "NSAllowsArbitraryLoadsInWebContent": true
            ]
        ]
        
        let mainTarget = Target(
            name: name,
            platform: platform,
            product: .app,
            bundleId: "com.duckduckgo.macos.browser.debug",
            infoPlist: .extendingDefault(with: infoPlist),
            sources: ["\(name)/Sources/**"],
            resources: ["\(name)/Resources/**"],
            headers: .headers(project: "\(name)/Headers/**"),
            entitlements: "\(name)/Other/DuckDuckGo.entitlements",
            dependencies: dependencies + [
                .package(product: "BrowserServicesKit"),
                .package(product: "Lottie"),
                .package(product: "OHHTTPStubs"),
                .package(product: "Punnycode"),
                .package(product: "Sparkle"),
                .package(product: "TrackerRadarKit"),
                .sdk(name: "WebKit", type: .framework, status: .required)
            ],
            settings: .settings(base: [
                "SWIFT_OBJC_BRIDGING_HEADER": "$(SRCROOT)/DuckDuckGo/Sources/Bridging.h",
                "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "FEEDBACK OUT_OF_APPSTORE $(inherited)",
                "ALWAYS_SEARCH_USER_PATHS": "NO",
                "CODE_SIGN_STYLE": "Automatic",
                "CODE_SIGN_IDENTITY": "Apple Development",
                "CLANG_ANALYZER_NONNULL": "YES",
                "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
                "CLANG_CXX_LANGUAGE_STANDARD": "gnu++14",
                "CLANG_CXX_LIBRARY": "libc++",
                "CLANG_ENABLE_MODULES": "YES",
                "CLANG_ENABLE_OBJC_ARC": "YES",
                "CLANG_ENABLE_OBJC_WEAK": "YES",
                "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
                "CLANG_WARN_BOOL_CONVERSION": "YES",
                "CLANG_WARN_COMMA": "YES",
                "CLANG_WARN_CONSTANT_CONVERSION": "YES",
                "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
                "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
                "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
                "CLANG_WARN_EMPTY_BODY": "YES",
                "CLANG_WARN_ENUM_CONVERSION": "YES",
                "CLANG_WARN_INFINITE_RECURSION": "YES",
                "CLANG_WARN_INT_CONVERSION": "YES",
                "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
                "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
                "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
                "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
                "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
                "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
                "CLANG_WARN_STRICT_PROTOTYPES": "YES",
                "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
                "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
                "CLANG_WARN_UNREACHABLE_CODE": "YES",
                "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
                "COPY_PHASE_STRIP": "NO",
                "DEVELOPMENT_TEAM": "HKE973VLUW",
                "ENABLE_STRICT_OBJC_MSGSEND": "YES",
                "GCC_C_LANGUAGE_STANDARD": "gnu11",
                "GCC_NO_COMMON_BLOCKS": "YES",
                "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
                "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
                "GCC_WARN_UNDECLARED_SELECTOR": "YES",
                "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
                "GCC_WARN_UNUSED_FUNCTION": "YES",
                "GCC_WARN_UNUSED_VARIABLE": "YES",
                "MACOSX_DEPLOYMENT_TARGET": "10.15",
                "MTL_FAST_MATH": "YES",
                "SDKROOT": "macosx"
            ]),
            coreDataModels: [
                .init("\(name)/CoreData/Bookmark.xcdatamodeld"),
                .init("\(name)/CoreData/Downloads.xcdatamodeld"),
                .init("\(name)/CoreData/Favicons.xcdatamodeld"),
                .init("\(name)/CoreData/FireproofDomains.xcdatamodeld"),
                .init("\(name)/CoreData/HTTPSUpgrade.xcdatamodeld"),
                .init("\(name)/CoreData/History.xcdatamodeld"),
                .init("\(name)/CoreData/Permissions.xcdatamodeld"),
                .init("\(name)/CoreData/PixelDataModel.xcdatamodeld"),
                .init("\(name)/CoreData/UnprotectedDomains.xcdatamodeld")
            ]
        )
        
        return [mainTarget]

//        let testTarget = Target(
//            name: "\(name)Tests",
//            platform: platform,
//            product: .unitTests,
//            bundleId: "io.tuist.\(name)Tests",
//            infoPlist: .default,
//            sources: ["Targets/\(name)/Tests/**"],
//            dependencies: [
//                .target(name: "\(name)")
//        ])
//        return [mainTarget, testTarget]
    }
}
