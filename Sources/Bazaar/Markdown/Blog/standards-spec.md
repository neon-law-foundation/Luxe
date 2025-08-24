# Sagebrush Standards Specification

## What Are Notations?

Notations are legal documents written in Markdown with YAML frontmatter that combine three core components into a
unified system:

1. **Documents**: Templates that dynamically incorporate client data using Liquid templating
2. **Questionnaires**: Interactive forms for data collection (flows for clients, alignments for staff)
3. **Workflows**: Automated actions triggered by responses

Each Notation is a single file that defines the complete workflow from data collection to document generation,
creating computable legal documents that ensure consistency and compliance.

## Notation File Structure

All Notations must begin with YAML frontmatter enclosed by `---` markers, followed by Markdown content:

```markdown
---
code: unique_identifier
title: Document Title (max 255 characters)
description: Brief description of the notation's purpose
respondent_type: org_and_person
flow:
  BEGIN:
    _: "question_reference"
  question_reference:
    _: "END"
alignment:
  BEGIN:
    _: "staff_review"
  staff_review:
    _: "END"
---

# Document Content

Dear {{client_name}},

This document confirms {{service_description}}...
```

## Required YAML Fields

### Basic Information

- **`code`**: Unique identifier for the notation (must be unique across all notations)

- **`title`**: Human-readable title (maximum 255 characters)

- **`description`**: Brief explanation of the notation's purpose

- **`respondent_type`**: Must be either `"org"` or `"org_and_person"`

### State Machines

- **`flow`**: Client questionnaire state machine

- **`alignment`**: Staff review state machine

Both state machines must:

- Include a `BEGIN` state as the entry point

- Have at least one path that leads to an `END` state

- Reference valid questions that exist in the database

- Avoid infinite loops or unreachable states

## Core Components

### 1. Documents

Documents are the final output of the Neon Notations system. They are generated using predefined templates that
dynamically incorporate client-specific information.

**Document Generation Methods:**

- **PDF Generation**: Uses `document_url` and `document_mappings` to populate existing PDF forms

- **Markdown Generation**: Uses `document_text` with Liquid templating for dynamic content creation

### 2. Questionnaires

Questionnaires are defined as state machines in the YAML frontmatter. Each state references a question that exists
in the database.

#### Flow State Machine (Client-Filled)

The `flow` section defines the client's questionnaire journey:

```yaml
flow:
  BEGIN:
    _: "what_is_your_name__personal_name"
  what_is_your_name__personal_name:
    "Yes": "do_you_have_children__yes_no"
    "No": "END"
  do_you_have_children__yes_no:
    _: "END"
```

**Flow Requirements:**

- Must start with a `BEGIN` state

- Must have at least one path to `END`

- Question references must exist in the database

- Supports conditional paths based on answer values

- Use `_` for unconditional transitions

#### Alignment State Machine (Staff-Filled)

The `alignment` section defines the staff review process:

```yaml
alignment:
  BEGIN:
    _: "staff_review__approve_reject"
  staff_review__approve_reject:
    "Approve": "END"
    "Reject": "rejection_reason__text"
  rejection_reason__text:
    _: "END"
```

**Alignment Requirements:**

- Must include `staff_review` for human verification

- Must start with `BEGIN` and reach `END`

- Enables quality control and legal oversight

- Supports multi-step approval processes

### 3. Workflows

Automated actions that are triggered by questionnaire responses to ensure continuous process progression and proper
handling of client requests.

**Workflow Capabilities:**

- Automated email notifications

- Document generation triggers

- Status updates and tracking

- Integration with external systems

- Escalation and reminder systems

## Process Flow

The Neon Notations system follows a structured process:

1. **Client Completes Flow**: Client fills out the initial questionnaire with their information and requirements
2. **Staff Reviews via Alignment**: Legal staff review the submission through alignment questionnaires
3. **Automated Workflows Execute**: System triggers appropriate automated actions based on responses
4. **Document Generation**: Final documents are generated using the collected and verified information

## Variable Interpolation

Notations use Liquid templating for dynamic content generation in the Markdown document body. Variables reference
answers from questionnaires or predefined client data.

### Basic Variable Syntax

```markdown
Dear {{client_name}},

Your organization {{organization_name}} has requested {{service_type}}.
```

### Question Answer References

Variables can reference specific questionnaire answers:

```markdown
Based on your response that you {{have_children}}, we recommend {{recommendation}}.

The effective date will be {{start_date | date: "%B %d, %Y"}}.
```

### Conditional Content

Use Liquid conditionals for dynamic document sections:

```markdown
{% if respondent_type == "org_and_person" %}
This agreement covers both the organization and individual signatory.
{% else %}
This agreement covers the organization only.
{% endif %}
```

### Available Filters

- `| date: "%format"` - Format dates

- `| currency` - Format monetary amounts

- `| capitalize` - Capitalize text

- `| strip` - Remove whitespace

## Validation Rules

The Notation validation service enforces strict compliance requirements:

### YAML Frontmatter Validation

- Must begin and end with `---` markers

- All required fields must be present and properly formatted

- YAML syntax must be valid

### Field Constraints

- **`code`**: Must be unique across all notations in the database

- **`title`**: Maximum 255 characters

- **`respondent_type`**: Must be exactly `"org"` or `"org_and_person"`

- **`description`**: Required, no length limit

### State Machine Validation

- Both `flow` and `alignment` must have `BEGIN` state

- Must have at least one reachable path to `END` state

- All question references must exist in the database

- No infinite loops or unreachable states allowed

- Conditional paths must reference valid answer values

### Variable Validation

- All `{{variable}}` references in document text are validated

- Variables must correspond to available question answers or client data

- Liquid syntax must be properly formatted

## Technical Implementation

### Document Templates

Templates support dynamic content generation through variable substitution and conditional logic:

- **Variable Substitution**: Replace placeholders with actual client data using Liquid templating

- **Conditional Content**: Show/hide sections based on questionnaire responses

- **Loop Structures**: Repeat content blocks for multiple items using Liquid loops

- **Date/Currency Formatting**: Apply filters for proper formatting

### Data Management

- **Database Persistence**: All questionnaire responses and workflow states are stored

- **Version Control**: Track changes and maintain audit trails

- **Data Validation**: Ensure data integrity and compliance requirements

- **Security**: Encrypt sensitive information and implement access controls

### Integration Guidelines

- **API Endpoints**: RESTful APIs for external system integration

- **Webhook Support**: Real-time notifications for status changes

- **Export Capabilities**: Support for various document formats

- **Authentication**: Secure access control and user management

## Implementation Standards

### Legal Compliance

- **Jurisdiction Requirements**: Include end dates for all agreements

- **Preferred Jurisdiction**: Use Nevada law and Washoe County when possible

- **Human Review**: Implement `staff_review` for human-in-the-loop verification

- **Audit Trail**: Maintain comprehensive logs of all actions and changes

### Technical Requirements

- **Liquid Templating**: Use Liquid templating engine for dynamic content

- **PDF Support**: Handle PDF form population and generation

- **Markdown Support**: Support Markdown for document creation

- **Cross-platform Compatibility**: Ensure system works across different platforms

### Quality Assurance

- **Validation Rules**: Implement comprehensive data validation

- **Error Handling**: Provide clear error messages and recovery options

- **Testing**: Thorough testing of all workflows and document generation

- **Performance**: Optimize for fast response times and scalability

## Complete Notation Example

Here's a complete example of a simple service agreement notation:

```markdown
---
code: simple_service_agreement
title: Simple Service Agreement
description: Basic service agreement template for consulting services
respondent_type: org_and_person
flow:
  BEGIN:
    _: "what_is_your_name__personal_name"
  what_is_your_name__personal_name:
    _: "what_is_service_type__text"
  what_is_service_type__text:
    _: "what_is_start_date__date"
  what_is_start_date__date:
    _: "END"
alignment:
  BEGIN:
    _: "staff_review__approve_reject"
  staff_review__approve_reject:
    "Approve": "END"
    "Reject": "rejection_reason__text"
  rejection_reason__text:
    _: "END"
---

# Service Agreement

**Agreement Date**: {{agreement_date | date: "%B %d, %Y"}}

This Service Agreement ("Agreement") is entered into between:

**Client**: {{client_name}}
**Service Provider**: Sagebrush Services

## Services

The Service Provider agrees to provide {{service_type}} services beginning on {{start_date | date: "%B %d, %Y"}}.

{% if respondent_type == "org_and_person" %}
This agreement binds both the organization and the individual signatory.
{% endif %}

## Terms

This agreement shall remain in effect until {{end_date | date: "%B %d, %Y"}}.

---

*Nothing in this document constitutes legal advice without a valid signed retainer.*
```

## Error Handling

When validation fails, the system provides specific error messages:

- **Missing Required Fields**: Lists which required YAML fields are missing

- **Invalid State Machines**: Identifies unreachable states or missing BEGIN/END states

- **Question Reference Errors**: Shows which question references don't exist in database

- **Variable Validation Errors**: Lists undefined variables in document text

- **Infinite Loop Detection**: Identifies circular state machine paths

## Contact Information

For questions, support, or implementation assistance, contact: **`standards@sagebrush.services`**

---

**Important Legal Notice**: "Nothing is legal advice without a valid signed retainer."

*This specification is maintained as part of the Sagebrush Standards project and serves as the technical
foundation for implementing computable legal document workflows.*
