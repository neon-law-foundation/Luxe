import Foundation
import Yams

struct BlogPost: Equatable, Identifiable {
    var id: String { slug }
    let title: String
    let slug: String
    let description: String
    let filename: String

    var githubUrl: String {
        "https://github.com/neon-law-foundation/Luxe/tree/main/Sources/Bazaar/Markdown/Blog/\(filename).md"
    }

    static func == (lhs: BlogPost, rhs: BlogPost) -> Bool {
        lhs.slug == rhs.slug
    }

    /// Parse frontmatter from markdown content using YAML parsing
    static func parseFrontmatter(from content: String, filename: String) -> BlogPost? {
        let lines = content.components(separatedBy: .newlines)

        guard lines.first == "---" else { return nil }

        var frontmatterLines: [String] = []
        var endIndex: Int?

        for (index, line) in lines.enumerated() {
            if index == 0 { continue }
            if line == "---" {
                endIndex = index
                break
            }
            frontmatterLines.append(line)
        }

        guard endIndex != nil else { return nil }

        // Join frontmatter lines and parse as YAML
        let frontmatterString = frontmatterLines.joined(separator: "\n")

        do {
            let yaml = try Yams.load(yaml: frontmatterString) as? [String: Any]
            guard let yaml = yaml,
                let title = yaml["title"] as? String,
                let slug = yaml["slug"] as? String,
                let description = yaml["description"] as? String
            else { return nil }

            return BlogPost(title: title, slug: slug, description: description, filename: filename)
        } catch {
            print("YAML parsing error for \(filename): \(error)")
            return nil
        }
    }

    /// Get all blog posts from the Markdown directory
    static func getAllPosts(workingDirectory: String = "") -> [BlogPost] {
        let markdownDirectory = workingDirectory + "Sources/Bazaar/Markdown/Blog"
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(atPath: markdownDirectory) else {
            return []
        }

        var posts: [BlogPost] = []

        for file in files where file.hasSuffix(".md") {
            let filePath = "\(markdownDirectory)/\(file)"
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8),
                let post = parseFrontmatter(from: content, filename: String(file.dropLast(3)))
            else {
                continue
            }
            posts.append(post)
        }

        return posts
    }

}
