import Foundation
import Testing

@testable import Bazaar

// import WebDriver

@Suite("Authentication WebDriver Tests", .serialized)
struct AuthenticationWebDriverTests {

    // All WebDriver tests are temporarily disabled due to compilation issues
    // TODO: Fix WebDriver imports and enable these tests

    // @Test(
    //     "Complete authentication flow: login -> logout -> login",
    //     .disabled("WebDriver compilation issues - fix imports first")
    // )
    // func completeAuthenticationFlow() async throws {
    //     // Setup WebDriver session
    //     let session = try await WebDriverSession.safari()
    //     defer { try? await session.close() }
    //
    //     let baseURL = "http://localhost:8080"
    //
    //     // Step 1: Visit home page and verify "Log In" button is visible
    //     try await session.navigate(to: "\(baseURL)/")
    //
    //     let loginButton = try await session.findElement(.linkText("Log In"))
    //     let loginButtonText = try await loginButton.text
    //     #expect(loginButtonText == "Log In")
    //
    //     // Verify "Log Out" button is NOT visible
    //     do {
    //         let _ = try await session.findElement(.linkText("Log Out"))
    //         Issue.record("Log Out button should not be visible when not authenticated")
    //     } catch WebDriverError.noSuchElement {
    //         // Expected - no logout button when not authenticated
    //     }
    //
    //     // Step 2: Click login button and authenticate with Keycloak
    //     try await loginButton.click()
    //
    //     // Wait for Keycloak redirect
    //     try await session.waitForElement(.name("username"), timeout: 10)
    //
    //     // Fill in credentials
    //     let usernameField = try await session.findElement(.name("username"))
    //     try await usernameField.sendKeys("admin@neonlaw.com")
    //
    //     let passwordField = try await session.findElement(.name("password"))
    //     try await passwordField.sendKeys("Vegas702!")
    //
    //     let submitButton = try await session.findElement(.name("login"))
    //     try await submitButton.click()
    //
    //     // Step 3: Verify we're back at the app and authentication state changed
    //     try await session.waitForElement(.linkText("Log Out"), timeout: 10)
    //
    //     let welcomeText = try await session.findElement(.xpath("//span[contains(text(), 'Welcome, admin@neonlaw.com')]"))
    //     let welcomeTextContent = try await welcomeText.text
    //     #expect(welcomeTextContent.contains("Welcome, admin@neonlaw.com"))
    //
    //     let logoutButton = try await session.findElement(.linkText("Log Out"))
    //     let logoutButtonText = try await logoutButton.text
    //     #expect(logoutButtonText == "Log Out")
    //
    //     // Verify "Log In" button is NOT visible
    //     do {
    //         let _ = try await session.findElement(.linkText("Log In"))
    //         Issue.record("Log In button should not be visible when authenticated")
    //     } catch WebDriverError.noSuchElement {
    //         // Expected - no login button when authenticated
    //     }
    //
    //     // Step 4: Visit /app/me to verify authenticated access
    //     try await session.navigate(to: "\(baseURL)/app/me")
    //
    //     let accountTitle = try await session.findElement(.xpath("//h1[contains(text(), 'My Account')]"))
    //     let accountTitleText = try await accountTitle.text
    //     #expect(accountTitleText.contains("My Account"))
    //
    //     // Verify user info is displayed
    //     let nameField = try await session.findElement(.xpath("//input[@value='Admin User']"))
    //     let nameValue = try await nameField.attribute("value")
    //     #expect(nameValue == "Admin User")
    //
    //     // Step 5: Click logout from the account page
    //     let accountLogoutButton = try await session.findElement(.linkText("🚪 Log Out"))
    //     try await accountLogoutButton.click()
    //
    //     // Step 6: Verify we're redirected to home and authentication state changed
    //     let currentURL = try await session.url
    //     #expect(currentURL.absoluteString == "\(baseURL)/")
    //
    //     // Wait for page to load and verify login button is back
    //     try await session.waitForElement(.linkText("Log In"), timeout: 5)
    //
    //     let loginButtonAfterLogout = try await session.findElement(.linkText("Log In"))
    //     let loginButtonAfterLogoutText = try await loginButtonAfterLogout.text
    //     #expect(loginButtonAfterLogoutText == "Log In")
    //
    //     // Verify "Log Out" button is NOT visible
    //     do {
    //         let _ = try await session.findElement(.linkText("Log Out"))
    //         Issue.record("Log Out button should not be visible after logout")
    //     } catch WebDriverError.noSuchElement {
    //         // Expected - no logout button after logout
    //     }
    //
    //     // Step 7: Try to access protected page - should redirect to Keycloak
    //     try await session.navigate(to: "\(baseURL)/app/me")
    //
    //     // Should be redirected to Keycloak login again
    //     try await session.waitForElement(.name("username"), timeout: 10)
    //
    //     let currentURLAfterLogout = try await session.url
    //     #expect(currentURLAfterLogout.absoluteString.contains("dex") || currentURLAfterLogout.absoluteString.contains("auth"))
    //
    //     // Step 8: Test second login to ensure session was properly cleared
    //     let usernameField2 = try await session.findElement(.name("username"))
    //     try await usernameField2.sendKeys("admin@neonlaw.com")
    //
    //     let passwordField2 = try await session.findElement(.name("password"))
    //     try await passwordField2.sendKeys("Vegas702!")
    //
    //     let submitButton2 = try await session.findElement(.name("login"))
    //     try await submitButton2.click()
    //
    //     // Should be back at /app/me with authentication
    //     try await session.waitForElement(.xpath("//h1[contains(text(), 'My Account')]"), timeout: 10)
    //
    //     let finalAccountTitle = try await session.findElement(.xpath("//h1[contains(text(), 'My Account')]"))
    //     let finalAccountTitleText = try await finalAccountTitle.text
    //     #expect(finalAccountTitleText.contains("My Account"))
    // }
    //
    // @Test(
    //     "Navigation button states persist across page navigation",
    //     .disabled("Requires running SagebrushWeb server, Keycloak, and ChromeDriver - run manually")
    // )
    // func navigationStatesPersistAcrossPages() async throws {
    //     let session = try await WebDriverSession.safari()
    //     defer { try? await session.close() }
    //
    //     let baseURL = "http://localhost:8080"
    //
    //     // Start unauthenticated and verify login button on all pages
    //     let pages = ["/", "/pricing", "/blog", "/virtual-mailbox"]
    //
    //     for page in pages {
    //         try await session.navigate(to: "\(baseURL)\(page)")
    //
    //         let loginButton = try await session.findElement(.linkText("Log In"))
    //         let loginButtonText = try await loginButton.text
    //         #expect(loginButtonText == "Log In", "Login button should be visible on \(page)")
    //
    //         // Verify no logout button
    //         do {
    //             let _ = try await session.findElement(.linkText("Log Out"))
    //             Issue.record("Log Out button should not be visible on \(page) when not authenticated")
    //         } catch WebDriverError.noSuchElement {
    //             // Expected
    //         }
    //     }
    //
    //     // Authenticate through first page
    //     try await session.navigate(to: "\(baseURL)/")
    //     let loginButton = try await session.findElement(.linkText("Log In"))
    //     try await loginButton.click()
    //
    //     // Complete authentication
    //     try await session.waitForElement(.name("username"), timeout: 10)
    //     let usernameField = try await session.findElement(.name("username"))
    //     try await usernameField.sendKeys("admin@neonlaw.com")
    //
    //     let passwordField = try await session.findElement(.name("password"))
    //     try await passwordField.sendKeys("Vegas702!")
    //
    //     let submitButton = try await session.findElement(.name("login"))
    //     try await submitButton.click()
    //
    //     // Verify authenticated state on all pages
    //     for page in pages {
    //         try await session.navigate(to: "\(baseURL)\(page)")
    //
    //         let welcomeText = try await session.findElement(.xpath("//span[contains(text(), 'Welcome, admin@neonlaw.com')]"))
    //         let welcomeTextContent = try await welcomeText.text
    //         #expect(welcomeTextContent.contains("Welcome, admin@neonlaw.com"), "Welcome message should be visible on \(page)")
    //
    //         let logoutButton = try await session.findElement(.linkText("Log Out"))
    //         let logoutButtonText = try await logoutButton.text
    //         #expect(logoutButtonText == "Log Out", "Logout button should be visible on \(page)")
    //
    //         // Verify no login button
    //         do {
    //             let _ = try await session.findElement(.linkText("Log In"))
    //             Issue.record("Log In button should not be visible on \(page) when authenticated")
    //         } catch WebDriverError.noSuchElement {
    //             // Expected
    //         }
    //     }
    // }
    //
    // @Test(
    //     "Logout from navigation header works from any page",
    //     .disabled("Requires running SagebrushWeb server, Keycloak, and ChromeDriver - run manually")
    // )
    // func logoutFromNavigationWorksFromAnyPage() async throws {
    //     let session = try await WebDriverSession.safari()
    //     defer { try? await session.close() }
    //
    //     let baseURL = "http://localhost:8080"
    //
    //     // Authenticate first
    //     try await session.navigate(to: "\(baseURL)/")
    //     let loginButton = try await session.findElement(.linkText("Log In"))
    //     try await loginButton.click()
    //
    //     try await session.waitForElement(.name("username"), timeout: 10)
    //     let usernameField = try await session.findElement(.name("username"))
    //     try await usernameField.sendKeys("admin@neonlaw.com")
    //
    //     let passwordField = try await session.findElement(.name("password"))
    //     try await passwordField.sendKeys("Vegas702!")
    //
    //     let submitButton = try await session.findElement(.name("login"))
    //     try await submitButton.click()
    //
    //     // Navigate to a different page
    //     try await session.navigate(to: "\(baseURL)/pricing")
    //
    //     // Verify we're authenticated
    //     let welcomeText = try await session.findElement(.xpath("//span[contains(text(), 'Welcome, admin@neonlaw.com')]"))
    //     let welcomeTextContent = try await welcomeText.text
    //     #expect(welcomeTextContent.contains("Welcome, admin@neonlaw.com"))
    //
    //     // Click logout from navigation
    //     let logoutButton = try await session.findElement(.linkText("Log Out"))
    //     try await logoutButton.click()
    //
    //     // Should be redirected to home page
    //     let currentURL = try await session.url
    //     #expect(currentURL.absoluteString == "\(baseURL)/")
    //
    //     // Verify we're logged out
    //     let loginButtonAfterLogout = try await session.findElement(.linkText("Log In"))
    //     let loginButtonText = try await loginButtonAfterLogout.text
    //     #expect(loginButtonText == "Log In")
    //
    //     // Verify trying to access protected page redirects to Keycloak
    //     try await session.navigate(to: "\(baseURL)/app/me")
    //     try await session.waitForElement(.name("username"), timeout: 10)
    //
    //     let finalURL = try await session.url
    //     #expect(finalURL.absoluteString.contains("dex") || finalURL.absoluteString.contains("auth"))
    // }
}
