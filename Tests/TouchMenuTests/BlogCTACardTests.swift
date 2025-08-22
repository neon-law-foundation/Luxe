import Elementary
import Testing

@testable import TouchMenu

@Suite("Blog CTA Card", .serialized)
struct BlogCTACardTests {

    @Suite("Content", .serialized)
    struct ContentTests {

        @Test("displays correct heading")
        func displaysCorrectHeading() {
            let component = BlogCTACard()
            let html = component.render()

            #expect(html.contains("<h3 class=\"title is-4 has-text-primary\">Ready to Experience the Benefits?</h3>"))
        }

        @Test("displays correct description text")
        func displaysCorrectDescriptionText() {
            let component = BlogCTACard()
            let html = component.render()

            #expect(
                html.contains(
                    "Join thousands of satisfied customers who have made the switch to physical address services. Our Nevada-based service offers all these benefits and more for just $49 per month."
                )
            )
        }

        @Test("mentions the $49 per month price")
        func mentionsMonthlyPrice() {
            let component = BlogCTACard()
            let html = component.render()

            #expect(html.contains("$49 per month"))
        }
    }

    @Suite("Call to Action Buttons", .serialized)
    struct CallToActionButtonsTests {

        @Test("includes View Pricing button with correct link")
        func includesViewPricingButton() {
            let component = BlogCTACard()
            let html = component.render()

            #expect(html.contains("<a class=\"button is-primary\" href=\"/pricing\">View Pricing</a>"))
        }

        @Test("includes Get Started button with correct email link")
        func includesGetStartedButton() {
            let component = BlogCTACard()
            let html = component.render()

            #expect(
                html.contains(
                    "<a class=\"button is-light\" href=\"mailto:support@sagebrush.services\">Get Started</a>"
                )
            )
        }

        @Test("buttons are in a buttons container")
        func buttonsAreInButtonsContainer() {
            let component = BlogCTACard()
            let html = component.render()

            #expect(html.contains("<div class=\"buttons\">"))
            #expect(html.contains("View Pricing"))
            #expect(html.contains("Get Started"))
        }
    }

    @Suite("HTML Structure", .serialized)
    struct HTMLStructureTests {

        @Test("uses box container with light background")
        func usesBoxContainerWithLightBackground() {
            let component = BlogCTACard()
            let html = component.render()

            #expect(html.contains("<div class=\"box has-background-light\">"))
        }

        @Test("has proper HTML structure")
        func hasProperHTMLStructure() {
            let component = BlogCTACard()
            let html = component.render()

            // Check that it starts with the box div
            #expect(html.contains("<div class=\"box has-background-light\">"))
            // Check that it contains the heading
            #expect(html.contains("<h3 class=\"title is-4 has-text-primary\">"))
            // Check that it contains a paragraph
            #expect(html.contains("<p>"))
            // Check that it contains the buttons div
            #expect(html.contains("<div class=\"buttons\">"))
            // Check that it ends properly
            #expect(html.contains("</div>"))
        }

        @Test("applies correct CSS classes")
        func appliesCorrectCSSClasses() {
            let component = BlogCTACard()
            let html = component.render()

            #expect(html.contains("class=\"box has-background-light\""))
            #expect(html.contains("class=\"title is-4 has-text-primary\""))
            #expect(html.contains("class=\"buttons\""))
            #expect(html.contains("class=\"button is-primary\""))
            #expect(html.contains("class=\"button is-light\""))
        }
    }
}
