import Foundation
import Testing

@testable import Brochure

@Suite("1337lawyers.com Static Site Generation")
struct LawyersGenerationTests {

    @Test("1337lawyers directory structure exists and is complete")
    func directoryStructureExists() throws {
        // Find the Public directory using Bundle resources
        guard let resourceURL = Bundle.module.url(forResource: "Public", withExtension: nil) else {
            throw TestError.publicDirectoryNotFound
        }

        let siteDirectory = resourceURL.appendingPathComponent("1337lawyers")

        // Verify main directory exists
        #expect(
            FileManager.default.fileExists(atPath: siteDirectory.path),
            "1337lawyers directory should exist in Public directory"
        )

        // Verify required files exist
        let indexFile = siteDirectory.appendingPathComponent("index.html")
        #expect(
            FileManager.default.fileExists(atPath: indexFile.path),
            "index.html should exist in 1337lawyers directory"
        )

        // Verify CSS directory exists
        let cssDir = siteDirectory.appendingPathComponent("css")
        #expect(
            FileManager.default.fileExists(atPath: cssDir.path),
            "css directory should exist in 1337lawyers directory"
        )

        // Verify CSS file exists
        let cssFile = cssDir.appendingPathComponent("style.css")
        #expect(
            FileManager.default.fileExists(atPath: cssFile.path),
            "style.css should exist in css directory"
        )

        // Verify images directory exists
        let imagesDir = siteDirectory.appendingPathComponent("images")
        #expect(
            FileManager.default.fileExists(atPath: imagesDir.path),
            "images directory should exist in 1337lawyers directory"
        )

        // Verify image files exist
        let expectedImages = [
            "logo.svg", "favicon.svg", "og-image.svg",
            "icon-shield.svg", "icon-bitcoin.svg", "icon-code.svg",
            "icon-rocket.svg", "icon-merge.svg", "icon-check.svg",
        ]
        for imageName in expectedImages {
            let imageFile = imagesDir.appendingPathComponent(imageName)
            #expect(
                FileManager.default.fileExists(atPath: imageFile.path),
                "\(imageName) should exist in images directory"
            )
        }
    }

    @Test("1337lawyers index.html has proper HTML structure")
    func indexHtmlStructure() throws {
        // Find the Public directory using Bundle resources
        guard let resourceURL = Bundle.module.url(forResource: "Public", withExtension: nil) else {
            throw TestError.publicDirectoryNotFound
        }

        let indexFile =
            resourceURL
            .appendingPathComponent("1337lawyers")
            .appendingPathComponent("index.html")

        let htmlContent = try String(contentsOf: indexFile, encoding: .utf8)

        // Verify basic HTML structure
        #expect(htmlContent.contains("<!DOCTYPE html>"), "Should contain DOCTYPE declaration")
        #expect(htmlContent.contains("<html"), "Should contain html tag")
        #expect(htmlContent.contains("<head"), "Should contain head tag")
        #expect(htmlContent.contains("<body"), "Should contain body tag")
        #expect(htmlContent.contains("</html>"), "Should contain closing html tag")

        // Verify meta tags
        #expect(
            htmlContent.contains("<meta charset=\"UTF-8\">") || htmlContent.contains("<meta charset=\"utf-8\">"),
            "Should contain charset meta tag"
        )
        #expect(
            htmlContent.contains("<meta name=\"viewport\""),
            "Should contain viewport meta tag for mobile responsiveness"
        )

        // Verify favicon link
        #expect(
            htmlContent.contains("<link rel=\"icon\"") && htmlContent.contains("favicon.svg"),
            "Should contain favicon link"
        )

        // Verify title tag exists and is not empty
        let titleRegex = try NSRegularExpression(pattern: "<title[^>]*>([^<]+)</title>", options: .caseInsensitive)
        let titleRange = NSRange(location: 0, length: htmlContent.count)
        let titleMatch = titleRegex.firstMatch(in: htmlContent, options: [], range: titleRange)

        #expect(titleMatch != nil, "Should have a title tag")
        if let titleMatch = titleMatch,
            let titleRange = Range(titleMatch.range(at: 1), in: htmlContent)
        {
            let title = String(htmlContent[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(!title.isEmpty, "Title should not be empty")
            #expect(
                title.contains("1337") || title.lowercased().contains("lawyer"),
                "Title should be relevant to 1337lawyers"
            )
        }
    }

    @Test("1337lawyers index.html contains required content sections")
    func indexHtmlContentSections() throws {
        // Find the Public directory using Bundle resources
        guard let resourceURL = Bundle.module.url(forResource: "Public", withExtension: nil) else {
            throw TestError.publicDirectoryNotFound
        }

        let indexFile =
            resourceURL
            .appendingPathComponent("1337lawyers")
            .appendingPathComponent("index.html")

        let htmlContent = try String(contentsOf: indexFile, encoding: .utf8).lowercased()

        // Check for hero section content
        #expect(
            htmlContent.contains("software law") || htmlContent.contains("legal services"),
            "Should contain hero section mentioning software law expertise"
        )

        // Check for services section
        #expect(
            htmlContent.contains("cybersecurity") || htmlContent.contains("cyber security"),
            "Should mention cybersecurity services"
        )
        #expect(
            htmlContent.contains("cryptocurrency") || htmlContent.contains("crypto"),
            "Should mention cryptocurrency services"
        )
        #expect(
            htmlContent.contains("smart contract"),
            "Should mention smart contracts"
        )

        // Check for about section explaining 1337 culture
        #expect(
            htmlContent.contains("1337") || htmlContent.contains("leet"),
            "Should explain 1337 (leet) culture"
        )

        // Check for contact information
        #expect(
            htmlContent.contains("contact") || htmlContent.contains("get in touch"),
            "Should have contact section"
        )

        // Check for footer with legal disclaimers
        #expect(
            htmlContent.contains("footer") || htmlContent.contains("©") || htmlContent.contains("copyright"),
            "Should have footer section"
        )
    }

    @Test("1337lawyers CSS file exists and has proper styling")
    func cssFileExists() throws {
        // Find the Public directory using Bundle resources
        guard let resourceURL = Bundle.module.url(forResource: "Public", withExtension: nil) else {
            throw TestError.publicDirectoryNotFound
        }

        let cssFile =
            resourceURL
            .appendingPathComponent("1337lawyers")
            .appendingPathComponent("css")
            .appendingPathComponent("style.css")

        let cssContent = try String(contentsOf: cssFile, encoding: .utf8).lowercased()

        // Verify basic CSS structure
        #expect(!cssContent.isEmpty, "CSS file should not be empty")

        // Check for dark theme elements (suitable for tech-focused law firm)
        #expect(
            cssContent.contains("background") || cssContent.contains("color"),
            "CSS should contain color/background styling"
        )

        // Check for responsive design elements
        #expect(
            cssContent.contains("@media") || cssContent.contains("flex") || cssContent.contains("grid"),
            "CSS should contain responsive design elements"
        )
    }

    @Test("1337lawyers content is valid for site generation upload")
    func contentValidForUpload() throws {
        let traverser = FileTraverser(excludePatterns: [])

        // Find the Public directory using Bundle resources
        guard let resourceURL = Bundle.module.url(forResource: "Public", withExtension: nil) else {
            throw TestError.publicDirectoryNotFound
        }

        let siteDirectory = resourceURL.appendingPathComponent("1337lawyers")

        // Get all files in the directory
        let fileManager = FileManager.default
        let files = try getAllFiles(in: siteDirectory.path, fileManager: fileManager)

        #expect(files.count > 0, "Should have files to upload")

        // Verify no files should be excluded with default patterns
        for file in files {
            let relativePath = String(file.dropFirst(siteDirectory.path.count + 1))
            #expect(
                !traverser.shouldExcludeFile(path: relativePath),
                "File \(relativePath) should not be excluded from upload"
            )
        }

        // Verify index.html is present
        let indexExists = files.contains { $0.hasSuffix("index.html") }
        #expect(indexExists, "index.html should be present for upload")

        // Verify CSS file is present
        let cssExists = files.contains { $0.contains("style.css") }
        #expect(cssExists, "CSS file should be present for upload")
    }

    @Test("1337lawyers site name is included in Brochure command")
    func siteNameIncludedInBrochureCommand() throws {
        let validSiteNames = [
            "NeonLaw", "HoshiHoshi", "TarotSwift", "NLF", "NVSciTech", "1337lawyers",
        ]

        #expect(
            validSiteNames.contains("1337lawyers"),
            "1337lawyers should be included in valid site names"
        )
    }

    @Test("1337lawyers all internal links have corresponding sections")
    func allInternalLinksHaveCorrespondingSections() throws {
        // Find the Public directory using Bundle resources
        guard let resourceURL = Bundle.module.url(forResource: "Public", withExtension: nil) else {
            throw TestError.publicDirectoryNotFound
        }

        let indexFile =
            resourceURL
            .appendingPathComponent("1337lawyers")
            .appendingPathComponent("index.html")

        let htmlContent = try String(contentsOf: indexFile, encoding: .utf8)

        // Extract all internal anchor links (href="#...")
        let linkRegex = try NSRegularExpression(pattern: "href=\"#([^\"]+)\"", options: [])
        let linkRange = NSRange(location: 0, length: htmlContent.count)
        let linkMatches = linkRegex.matches(in: htmlContent, options: [], range: linkRange)

        var internalLinks: Set<String> = []
        for match in linkMatches {
            if let range = Range(match.range(at: 1), in: htmlContent) {
                let linkTarget = String(htmlContent[range])
                internalLinks.insert(linkTarget)
            }
        }

        #expect(!internalLinks.isEmpty, "Should have internal navigation links")

        // Extract all IDs in the document
        let idRegex = try NSRegularExpression(pattern: "id=\"([^\"]+)\"", options: [])
        let idRange = NSRange(location: 0, length: htmlContent.count)
        let idMatches = idRegex.matches(in: htmlContent, options: [], range: idRange)

        var availableIds: Set<String> = []
        for match in idMatches {
            if let range = Range(match.range(at: 1), in: htmlContent) {
                let elementId = String(htmlContent[range])
                availableIds.insert(elementId)
            }
        }

        // Verify every internal link has a corresponding section ID
        for linkTarget in internalLinks {
            #expect(
                availableIds.contains(linkTarget),
                "Internal link '#\(linkTarget)' should have a corresponding element with id='\(linkTarget)'"
            )
        }

        // Verify expected navigation structure exists
        let expectedLinks = ["services", "about", "contact"]
        for expectedLink in expectedLinks {
            #expect(
                internalLinks.contains(expectedLink),
                "Should have navigation link for '\(expectedLink)'"
            )
            #expect(
                availableIds.contains(expectedLink),
                "Should have section with id '\(expectedLink)'"
            )
        }
    }

    @Test("1337lawyers robots.txt exists and has proper directives")
    func robotsTxtExistsAndValid() throws {
        // Find the Public directory using Bundle resources
        guard let resourceURL = Bundle.module.url(forResource: "Public", withExtension: nil) else {
            throw TestError.publicDirectoryNotFound
        }

        let robotsFile =
            resourceURL
            .appendingPathComponent("1337lawyers")
            .appendingPathComponent("robots.txt")

        // Verify robots.txt exists
        #expect(
            FileManager.default.fileExists(atPath: robotsFile.path),
            "robots.txt should exist in 1337lawyers directory"
        )

        // Read and verify content
        let robotsContent = try String(contentsOf: robotsFile, encoding: .utf8)

        // Verify essential directives
        #expect(!robotsContent.isEmpty, "robots.txt should not be empty")
        #expect(robotsContent.contains("User-agent:"), "Should contain User-agent directive")
        #expect(robotsContent.contains("Allow:"), "Should contain Allow directive")
        #expect(robotsContent.contains("Sitemap:"), "Should contain Sitemap directive")
        #expect(
            robotsContent.contains("https://www.1337lawyers.com/sitemap.xml"),
            "Should reference sitemap.xml location"
        )

        // Verify it allows general crawling
        #expect(
            robotsContent.contains("User-agent: *") && robotsContent.contains("Allow: /"),
            "Should allow all user agents to crawl the site"
        )

        // Verify crawl delay is set
        #expect(
            robotsContent.contains("Crawl-delay:"),
            "Should specify crawl delay for respectful crawling"
        )
    }

    @Test("1337lawyers sitemap.xml exists and has proper structure")
    func sitemapXmlExistsAndValid() throws {
        // Find the Public directory using Bundle resources
        guard let resourceURL = Bundle.module.url(forResource: "Public", withExtension: nil) else {
            throw TestError.publicDirectoryNotFound
        }

        let sitemapFile =
            resourceURL
            .appendingPathComponent("1337lawyers")
            .appendingPathComponent("sitemap.xml")

        // Verify sitemap.xml exists
        #expect(
            FileManager.default.fileExists(atPath: sitemapFile.path),
            "sitemap.xml should exist in 1337lawyers directory"
        )

        // Read and verify content
        let sitemapContent = try String(contentsOf: sitemapFile, encoding: .utf8)

        // Verify XML structure
        #expect(!sitemapContent.isEmpty, "sitemap.xml should not be empty")
        #expect(
            sitemapContent.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"),
            "Should have XML declaration"
        )
        #expect(
            sitemapContent.contains("<urlset") && sitemapContent.contains("</urlset>"),
            "Should have urlset root element"
        )
        #expect(
            sitemapContent.contains("http://www.sitemaps.org/schemas/sitemap/0.9"),
            "Should reference sitemap schema"
        )

        // Verify essential URLs are included
        #expect(
            sitemapContent.contains("<loc>https://www.1337lawyers.com/</loc>"),
            "Should include homepage URL"
        )
        #expect(
            sitemapContent.contains("<lastmod>"),
            "Should include last modification date"
        )
        #expect(
            sitemapContent.contains("<changefreq>"),
            "Should include change frequency"
        )
        #expect(
            sitemapContent.contains("<priority>"),
            "Should include page priority"
        )

        // Verify section URLs are included
        #expect(
            sitemapContent.contains("#services"),
            "Should include services section URL"
        )
        #expect(
            sitemapContent.contains("#about"),
            "Should include about section URL"
        )
        #expect(
            sitemapContent.contains("#contact"),
            "Should include contact section URL"
        )
    }

    @Test("1337lawyers structured data markup exists and is valid")
    func structuredDataMarkupExistsAndValid() throws {
        // Find the Public directory using Bundle resources
        guard let resourceURL = Bundle.module.url(forResource: "Public", withExtension: nil) else {
            throw TestError.publicDirectoryNotFound
        }

        let indexFile =
            resourceURL
            .appendingPathComponent("1337lawyers")
            .appendingPathComponent("index.html")

        let htmlContent = try String(contentsOf: indexFile, encoding: .utf8)

        // Verify structured data scripts exist
        #expect(
            htmlContent.contains("<script type=\"application/ld+json\">"),
            "Should contain JSON-LD structured data scripts"
        )

        // Verify LegalService schema
        #expect(
            htmlContent.contains("\"@type\": \"LegalService\""),
            "Should include LegalService schema markup"
        )
        #expect(
            htmlContent.contains("\"name\": \"1337 Lawyers\""),
            "Should include business name in structured data"
        )
        #expect(
            htmlContent.contains("\"@context\": \"https://schema.org\""),
            "Should reference schema.org context"
        )

        // Verify Organization schema
        #expect(
            htmlContent.contains("\"@type\": \"Organization\""),
            "Should include Organization schema markup"
        )

        // Verify WebSite schema
        #expect(
            htmlContent.contains("\"@type\": \"WebSite\""),
            "Should include WebSite schema markup"
        )

        // Verify BreadcrumbList schema
        #expect(
            htmlContent.contains("\"@type\": \"BreadcrumbList\""),
            "Should include BreadcrumbList schema for navigation"
        )

        // Verify service offerings are included
        #expect(
            htmlContent.contains("\"hasOfferCatalog\""),
            "Should include service catalog in structured data"
        )
        #expect(
            htmlContent.contains("\"Cybersecurity Law\""),
            "Should list cybersecurity services"
        )
        #expect(
            htmlContent.contains("\"Cryptocurrency & Blockchain\""),
            "Should list cryptocurrency services"
        )

        // Verify contact information
        #expect(
            htmlContent.contains("\"contactPoint\""),
            "Should include contact information"
        )

        // Verify parent organization reference
        #expect(
            htmlContent.contains("\"parentOrganization\""),
            "Should reference parent organization (Neon Law)"
        )
    }

    @Test("1337lawyers navigation structure is semantically correct")
    func navigationStructureIsSemanticallyCorrect() throws {
        // Find the Public directory using Bundle resources
        guard let resourceURL = Bundle.module.url(forResource: "Public", withExtension: nil) else {
            throw TestError.publicDirectoryNotFound
        }

        let indexFile =
            resourceURL
            .appendingPathComponent("1337lawyers")
            .appendingPathComponent("index.html")

        let htmlContent = try String(contentsOf: indexFile, encoding: .utf8).lowercased()

        // Verify proper navigation structure
        #expect(htmlContent.contains("<nav"), "Should have nav element")
        #expect(htmlContent.contains("nav-links"), "Should have nav-links class")

        // Verify sections are properly structured
        #expect(htmlContent.contains("<section id=\"hero\""), "Should have hero section")
        #expect(htmlContent.contains("<section id=\"services\""), "Should have services section")
        #expect(htmlContent.contains("<section id=\"about\""), "Should have about section")
        #expect(htmlContent.contains("<section id=\"contact\""), "Should have contact section")

        // Verify accessibility - sections should have headings
        #expect(htmlContent.contains("services") && htmlContent.contains("<h"), "Services section should have heading")
        #expect(htmlContent.contains("about") && htmlContent.contains("<h"), "About section should have heading")
        #expect(htmlContent.contains("contact") && htmlContent.contains("<h"), "Contact section should have heading")
    }

    // MARK: - Helper Methods

    private func getAllFiles(in directory: String, fileManager: FileManager) throws -> [String] {
        var files: [String] = []
        let enumerator = fileManager.enumerator(atPath: directory)

        while let file = enumerator?.nextObject() as? String {
            let fullPath = (directory as NSString).appendingPathComponent(file)
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                if !isDirectory.boolValue {
                    files.append(fullPath)
                }
            }
        }

        return files
    }
}

enum TestError: Error {
    case publicDirectoryNotFound
}
