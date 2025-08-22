import TouchMenu
import Vapor
import VaporElementary

func configureApp(_ app: Application) throws {
    app.get("health") { _ in
        "OK"
    }

    app.get("version") { req async throws -> Response in
        let version = Version(serviceName: "Destined")
        let jsonData = try version.toJSON()
        let response = Response(status: .ok, body: .init(data: jsonData))
        response.headers.contentType = .json
        return response
    }

    app.get { _ in
        HTMLResponse {
            HomePage()
        }
    }

    app.get("scorpio") { _ in
        HTMLResponse {
            ScorpioPage()
        }
    }

    app.get("scorpio", "moon") { _ in
        HTMLResponse {
            ScorpioMoonPage()
        }
    }

    app.get("about-astrocartography") { _ in
        HTMLResponse {
            AboutAstrocartographyPage()
        }
    }

    app.get("services") { _ in
        HTMLResponse {
            ServicesPage()
        }
    }

    app.get("blog") { _ in
        HTMLResponse {
            BlogPage()
        }
    }

    app.get("blog", "neptune-line") { _ in
        HTMLResponse {
            NeptuneLinePage()
        }
    }

    app.get("privacy-policy") { _ in
        HTMLResponse {
            PrivacyPolicyPage()
        }
    }
}
