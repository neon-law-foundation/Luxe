import Foundation

struct BlogPost: Equatable {
    let title: String
    let slug: String
    let description: String
    let filename: String

    var githubUrl: String {
        "https://github.com/neon-law-foundation/Luxe/tree/main/Sources/Bazaar/Markdown/\(filename).md"
    }

    static func == (lhs: BlogPost, rhs: BlogPost) -> Bool {
        lhs.slug == rhs.slug
    }

    /// Parse frontmatter from markdown content
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

        var title: String?
        var slug: String?
        var description: String?

        for line in frontmatterLines {
            let components = line.components(separatedBy: ": ")
            guard components.count >= 2 else { continue }

            let key = components[0].trimmingCharacters(in: .whitespaces)
            let value = components[1...].joined(separator: ": ")
                .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\"")))

            switch key {
            case "title":
                title = value
            case "slug":
                slug = value
            case "description":
                description = value
            case "created_at":
                // Skip date fields - we no longer use them
                break
            default:
                break
            }
        }

        guard let title = title,
            let slug = slug,
            let description = description
        else {
            return nil
        }

        return BlogPost(title: title, slug: slug, description: description, filename: filename)
    }

    /// Get all blog posts from the Markdown directory
    static func getAllPosts(workingDirectory: String = "") -> [BlogPost] {
        let markdownDirectory = workingDirectory + "Sources/Bazaar/Markdown"
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
