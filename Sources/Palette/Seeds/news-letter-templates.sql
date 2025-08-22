-- Insert default newsletter templates for each newsletter type
INSERT INTO marketing.newsletter_templates (id, name, description, template_content, category, created_by)
VALUES
-- NV Sci Tech Newsletter Template
(
    '550e8400-e29b-41d4-a716-446655440001',
    'NV Sci Tech Standard',
    'Standard template for NV Sci Tech newsletter with research highlights',
    '# 🔬 NV Sci Tech Newsletter

{{ date }}

Welcome to this week''s Nevada Science and Technology update!

## Featured Research

{{ featured_research }}

## Technology Updates

{{ tech_updates }}

## Upcoming Events

{{ upcoming_events }}

## Community Spotlight

{{ community_spotlight }}

---

*Stay curious and keep innovating!*

**The NV Sci Tech Team**

*Nevada Science and Technology Newsletter*
Email: team@nvscitech.org
Website: https://nvscitech.org',
    'newsletter',
    (
        SELECT id FROM auth.users
        WHERE username = 'admin@sagebrush.services'
        LIMIT 1
    )
),

-- Sagebrush Newsletter Template
(
    '550e8400-e29b-41d4-a716-446655440002',
    'Sagebrush Standard',
    'Standard template for Sagebrush services newsletter with company updates',
    '# 🌾 Sagebrush Newsletter

{{ date }}

Hello from the Sagebrush team!

## This Month''s Highlights

{{ monthly_highlights }}

## Service Updates

{{ service_updates }}

## Client Success Stories

{{ success_stories }}

## What''s Coming Next

{{ coming_next }}

---

*Thank you for being part of the Sagebrush community!*

**The Sagebrush Team**

*Sagebrush Services Newsletter*
Email: support@sagebrush.services
Website: https://sagebrush.services',
    'newsletter',
    (
        SELECT id FROM auth.users
        WHERE username = 'admin@sagebrush.services'
        LIMIT 1
    )
),

-- Neon Law Newsletter Template
(
    '550e8400-e29b-41d4-a716-446655440003',
    'Neon Law Standard',
    'Standard template for Neon Law newsletter with legal updates and insights',
    '# ⚖️ Neon Law Newsletter

{{ date }}

Legal insights and updates from Neon Law.

## Legal Updates

{{ legal_updates }}

## Case Law Highlights

{{ case_law }}

## Regulatory Changes

{{ regulatory_changes }}

## Access to Justice

{{ access_to_justice }}

---

*Empowering justice through technology and open source.*

**The Neon Law Team**

*Neon Law Newsletter*
Email: admin@neonlaw.com
Website: https://neonlaw.com',
    'newsletter',
    (
        SELECT id FROM auth.users
        WHERE username = 'admin@sagebrush.services'
        LIMIT 1
    )
),

-- General Announcement Template
(
    '550e8400-e29b-41d4-a716-446655440004',
    'General Announcement',
    'Template for important announcements across all newsletters',
    '# 📢 Important Announcement

{{ date }}

## {{ announcement_title }}

{{ announcement_content }}

## What This Means for You

{{ impact_description }}

## Next Steps

{{ next_steps }}

---

*For questions or concerns, please don''t hesitate to reach out.*

**{{ sender_team }}**',
    'announcement',
    (
        SELECT id FROM auth.users
        WHERE username = 'admin@sagebrush.services'
        LIMIT 1
    )
);
