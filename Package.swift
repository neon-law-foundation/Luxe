// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Luxe",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        // Server scaffolding
        .package(url: "https://github.com/vapor/vapor", from: "4.115.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle", from: "2.8.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.8.2"),
        .package(url: "https://github.com/swift-server/swift-openapi-vapor", from: "1.0.1"),

        // Observability
        .package(url: "https://github.com/apple/swift-log", .upToNextMajor(from: "1.6.3")),

        // Database
        .package(url: "https://github.com/vapor/fluent.git", from: "4.12.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.10.1"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.26.2"),

        // HTML pages
        .package(url: "https://github.com/vapor-community/vapor-elementary.git", from: "0.2.1"),

        // AWS
        .package(url: "https://github.com/soto-project/soto.git", from: "7.7.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),

        // for CLi
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.1"),

        // Markdown processing
        .package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main"),

        // JWT and OIDC
        .package(url: "https://github.com/vapor/jwt.git", from: "5.0.0"),

        // MCP
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),

        // JSON Schema validation
        .package(url: "https://github.com/ajevans99/swift-json-schema", from: "0.8.0"),

        // WebDriver for integration testing
        .package(url: "https://github.com/thebrowsercompany/swift-webdriver.git", branch: "main"),

        // YAML parsing
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),

        // Cryptography
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),

        // OAuth authentication
        .package(url: "https://github.com/vapor-community/Imperial.git", from: "2.0.0"),

        // Queue system with Redis
        .package(url: "https://github.com/vapor/queues.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Vegas",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SotoCloudFormation", package: "soto"),
                .product(name: "SotoEC2", package: "soto"),
                .product(name: "SotoECS", package: "soto"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
            ],
            exclude: [
                "README.md",
                "S3_BUCKET_STRUCTURE.md",
            ]
        ),
        .executableTarget(
            name: "Holiday",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "SotoS3", package: "soto"),
                .product(name: "SotoECS", package: "soto"),
                .product(name: "SotoElasticLoadBalancingV2", package: "soto"),
                .product(name: "SotoCloudFormation", package: "soto"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            exclude: [
                "README.md"
            ]
        ),
        .target(
            name: "Dali",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SotoSES", package: "soto"),
                .product(name: "JSONSchema", package: "swift-json-schema"),
                .product(name: "Yams", package: "Yams"),
            ],
            exclude: [
                "README.md"
            ]
        ),
        .executableTarget(
            name: "Bazaar",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "VaporElementary", package: "vapor-elementary"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIVapor", package: "swift-openapi-vapor"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Queues", package: "queues"),
                .product(name: "QueuesRedisDriver", package: "queues-redis-driver"),
                .product(name: "SotoSES", package: "soto"),
                "TouchMenu",
                "Dali",
                "Bouncer",
            ],
            exclude: [
                "Dockerfile",
                "Public/",
            ],
            resources: [
                .copy("Markdown"),
                .copy("Notations"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        .target(
            name: "PaperPusher",
        ),
        .executableTarget(
            name: "Concierge",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            exclude: [
                "README.md"
            ]
        ),
        .executableTarget(
            name: "NeonLaw"
        ),
        .target(
            name: "Bouncer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "Imperial", package: "Imperial"),
                "Dali",
            ],
            exclude: [
                "README.md",
                "ImperialIntegrationAnalysis.md",
            ]
        ),
        .target(
            name: "Ace",
        ),
        .target(
            name: "Sagebrush",
        ),
        .executableTarget(
            name: "Destined",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "VaporElementary", package: "vapor-elementary"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Logging", package: "swift-log"),
                "TouchMenu",
            ],
            exclude: [
                "Dockerfile",
                "README.md",
                "Markdown/",
            ],
            resources: [
                .copy("Public")
            ]
        ),
        .executableTarget(
            name: "RebelAI",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log"),
            ],
            exclude: [
                "README.md"
            ]
        ),
        .executableTarget(
            name: "Palette",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Yams", package: "Yams"),
                "Dali",
            ],
            exclude: [
                "Migrations/",
                "README.md",
            ],
            resources: [
                .copy("Seeds")
            ]
        ),
        .executableTarget(
            name: "Wayne",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            exclude: [
                "README.md"
            ]
        ),
        .testTarget(
            name: "RebelAITests",
            dependencies: [
                "RebelAI"
            ]
        ),
        .testTarget(
            name: "PaletteTests",
            dependencies: [
                "Palette",
                "Dali",
                "DaliTests",
                "TestUtilities",
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Yams", package: "Yams"),
            ]
        ),
        .testTarget(
            name: "DaliTests",
            dependencies: [
                "Dali",
                "Palette",
                "TestUtilities",
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .testTarget(
            name: "BazaarTests",
            dependencies: [
                "Bazaar",
                "Dali",
                "Bouncer",
                "Palette",
                "TestUtilities",
                .product(name: "VaporTesting", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "WebDriver", package: "swift-webdriver"),
            ],
            exclude: [
                "INTEGRATION_TESTS.md"
            ]
        ),
        .testTarget(
            name: "VegasTests",
            dependencies: [
                "Vegas"
            ]
        ),
        .target(
            name: "FoodCart",
        ),
        .target(
            name: "TouchMenu",
            dependencies: [
                .product(name: "VaporElementary", package: "vapor-elementary"),
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .target(
            name: "TestUtilities",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Vapor", package: "vapor"),
                "Dali",
                "Palette",
            ]
        ),
        .testTarget(
            name: "BouncerTests",
            dependencies: [
                "Bouncer",
                "Dali",
                "TestUtilities",
                .product(name: "VaporTesting", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
            ]
        ),
        .testTarget(
            name: "TouchMenuTests",
            dependencies: [
                "TouchMenu"
            ],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "HolidayTests",
            dependencies: [
                "Holiday"
            ]
        ),
        .testTarget(
            name: "DestinedTests",
            dependencies: [
                "Destined",
                "TestUtilities",
                .product(name: "VaporTesting", package: "vapor"),
            ],
        ),
        .testTarget(
            name: "ConciergeTests",
            dependencies: [
                "Concierge"
            ]
        ),
        .testTarget(
            name: "WayneTests",
            dependencies: [
                "Wayne"
            ]
        ),
        .executableTarget(
            name: "MiseEnPlace",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ],
            exclude: [
                "README.md"
            ]
        ),
        .executableTarget(
            name: "Brochure",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SotoS3", package: "soto"),
                .product(name: "SotoCloudFront", package: "soto"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            exclude: [
                "README.md"
            ],
            resources: [
                .copy("Public")
            ]
        ),
        .testTarget(
            name: "MiseEnPlaceTests",
            dependencies: [
                "MiseEnPlace"
            ]
        ),
        .executableTarget(
            name: "Standards",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "Logging", package: "swift-log"),
            ],
            exclude: [
                "README.md"
            ]
        ),
        .testTarget(
            name: "BrochureTests",
            dependencies: [
                "Brochure",
                "TestUtilities",
                .product(name: "WebDriver", package: "swift-webdriver"),
            ],
            exclude: [
                "1337LawyersAccessibilityChecklist.md"
            ]
        ),
        .testTarget(
            name: "StandardsTests",
            dependencies: [
                "Standards"
            ]
        ),
    ]
)
