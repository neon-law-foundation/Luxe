import Testing

@testable import Brochure

@Suite("FileTraverser functionality", .serialized)
struct FileTraverserTests {

    @Test("Empty exclude patterns allow all files")
    func emptyExcludePatternsAllowAllFiles() {
        let traverser = FileTraverser(excludePatterns: [])

        #expect(traverser.shouldExcludeFile(path: "index.html") == false)
        #expect(traverser.shouldExcludeFile(path: "css/style.css") == false)
        #expect(traverser.shouldExcludeFile(path: "js/main.js") == false)
        #expect(traverser.shouldExcludeFile(path: "images/logo.png") == false)
    }

    @Test("Simple filename exclusion works")
    func simpleFilenameExclusion() {
        let traverser = FileTraverser(excludePatterns: ["*.log", "*.tmp"])

        #expect(traverser.shouldExcludeFile(path: "debug.log") == true)
        #expect(traverser.shouldExcludeFile(path: "temp.tmp") == true)
        #expect(traverser.shouldExcludeFile(path: "index.html") == false)
        #expect(traverser.shouldExcludeFile(path: "style.css") == false)
    }

    @Test("Directory exclusion works")
    func directoryExclusion() {
        let traverser = FileTraverser(excludePatterns: ["node_modules/**", ".git/**"])

        #expect(traverser.shouldExcludeFile(path: "node_modules/package.json") == true)
        #expect(traverser.shouldExcludeFile(path: "node_modules/lib/index.js") == true)
        #expect(traverser.shouldExcludeFile(path: ".git/config") == true)
        #expect(traverser.shouldExcludeFile(path: "src/main.js") == false)
        #expect(traverser.shouldExcludeFile(path: "package.json") == false)
    }

    @Test("Single asterisk matches within directory")
    func singleAsteriskMatching() {
        let traverser = FileTraverser(excludePatterns: ["*.min.js", "temp*"])

        #expect(traverser.shouldExcludeFile(path: "app.min.js") == true)
        #expect(traverser.shouldExcludeFile(path: "vendor.min.js") == true)
        #expect(traverser.shouldExcludeFile(path: "tempfile.txt") == true)
        #expect(traverser.shouldExcludeFile(path: "temp") == true)
        #expect(traverser.shouldExcludeFile(path: "app.js") == false)
        #expect(traverser.shouldExcludeFile(path: "css/temp.css") == false)  // * doesn't cross directories
    }

    @Test("Double asterisk matches across directories")
    func doubleAsteriskMatching() {
        let traverser = FileTraverser(excludePatterns: ["**/*.min.js", "**/temp/**"])

        #expect(traverser.shouldExcludeFile(path: "app.min.js") == true)
        #expect(traverser.shouldExcludeFile(path: "js/vendor.min.js") == true)
        #expect(traverser.shouldExcludeFile(path: "assets/js/bundle.min.js") == true)
        #expect(traverser.shouldExcludeFile(path: "temp/file.txt") == true)
        #expect(traverser.shouldExcludeFile(path: "src/temp/data.json") == true)
        #expect(traverser.shouldExcludeFile(path: "app.js") == false)
        #expect(traverser.shouldExcludeFile(path: "js/main.js") == false)
    }

    @Test("Question mark matches single character")
    func questionMarkMatching() {
        let traverser = FileTraverser(excludePatterns: ["test?.log", "file?.txt"])

        #expect(traverser.shouldExcludeFile(path: "test1.log") == true)
        #expect(traverser.shouldExcludeFile(path: "testa.log") == true)
        #expect(traverser.shouldExcludeFile(path: "file2.txt") == true)
        #expect(traverser.shouldExcludeFile(path: "test.log") == false)  // No character to match
        #expect(traverser.shouldExcludeFile(path: "test12.log") == false)  // Too many characters
        #expect(traverser.shouldExcludeFile(path: "test1.txt") == false)  // Wrong extension
    }

    @Test("Complex patterns work correctly")
    func complexPatterns() {
        let traverser = FileTraverser(excludePatterns: [
            "*.DS_Store",
            "**/.git/**",
            "node_modules/**",
            "**/*.min.*",
            "temp*",
            "*.tmp",
        ])

        // Should be excluded
        #expect(traverser.shouldExcludeFile(path: ".DS_Store") == true)
        #expect(traverser.shouldExcludeFile(path: "images/.DS_Store") == true)
        #expect(traverser.shouldExcludeFile(path: ".git/config") == true)
        #expect(traverser.shouldExcludeFile(path: "src/.git/hooks/pre-commit") == true)
        #expect(traverser.shouldExcludeFile(path: "node_modules/package.json") == true)
        #expect(traverser.shouldExcludeFile(path: "app.min.js") == true)
        #expect(traverser.shouldExcludeFile(path: "css/style.min.css") == true)
        #expect(traverser.shouldExcludeFile(path: "tempfile.txt") == true)
        #expect(traverser.shouldExcludeFile(path: "backup.tmp") == true)

        // Should not be excluded
        #expect(traverser.shouldExcludeFile(path: "index.html") == false)
        #expect(traverser.shouldExcludeFile(path: "css/style.css") == false)
        #expect(traverser.shouldExcludeFile(path: "js/main.js") == false)
        #expect(traverser.shouldExcludeFile(path: "images/logo.png") == false)
        #expect(traverser.shouldExcludeFile(path: "package.json") == false)
    }

    @Test("String extension parseExcludePatterns works correctly")
    func parseExcludePatternsExtension() {
        let patterns1 = "*.log,*.tmp,node_modules/**"
        let result1 = patterns1.parseExcludePatterns()
        #expect(result1 == ["*.log", "*.tmp", "node_modules/**"])

        let patterns2 = "  *.DS_Store  ,  **/.git/**  ,  temp*  "
        let result2 = patterns2.parseExcludePatterns()
        #expect(result2 == ["*.DS_Store", "**/.git/**", "temp*"])

        let patterns3 = ""
        let result3 = patterns3.parseExcludePatterns()
        #expect(result3.isEmpty)

        let patterns4 = "single-pattern"
        let result4 = patterns4.parseExcludePatterns()
        #expect(result4 == ["single-pattern"])
    }

    @Test("Special regex characters are escaped properly")
    func specialCharactersEscaped() {
        let traverser = FileTraverser(excludePatterns: ["file.with.dots", "file+plus", "file(parens)"])

        #expect(traverser.shouldExcludeFile(path: "file.with.dots") == true)
        #expect(traverser.shouldExcludeFile(path: "fileXwithXdots") == false)  // Dots should be literal
        #expect(traverser.shouldExcludeFile(path: "file+plus") == true)
        #expect(traverser.shouldExcludeFile(path: "file(parens)") == true)
    }
}
