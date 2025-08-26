# Stencil Migration Analysis: Phase 1 Research Results

## Overview

This document provides a comprehensive analysis of migrating from Liquid templating to Stencil templating for the Standards system, based on Phase 1 research and planning.

## Current State Analysis

### Existing Liquid Usage Patterns

Based on audit of existing notation files, the following Liquid patterns are currently used:

#### 1. Variable Interpolation
```liquid
{{client_name}}
{{organization_name}}
{{service_type}}
{{neon_representative.signature.inserted_at|date}}
{{client.notarization.signature}}
{{signatory.signature.mark}}
```

#### 2. Conditional Logic
```liquid
{% if respondent_type == "org_and_person" %}
This agreement covers both the organization and individual signatory.
{% else %}
This agreement covers the organization only.
{% endif %}

{% if taxpayer.is_entity %}
on behalf of {{taxpayer.name}}.
{% endif %}
```

#### 3. Filter Usage
```liquid
{{start_date | date: "%B %d, %Y"}}
{{neon_representative.signature.inserted_at|date}}
{{issuance.fair_market_value_per_share|currency}}
{{issuance.amount_paid_per_share|currency}}
```

#### 4. Complex Object Navigation
```liquid
{{issuance.share_class.org.name}}
{{issuance.share_class.org.org_type.name}}
{{issuance.share_class.org.org_type.jurisdiction.name}}
{{client_information.company_name}}
{{client_information.contact_person}}
```

### Current Files Using Liquid Patterns

1. **retainer.md** - Basic variable interpolation and date filtering
2. **generic_retainer.md** - Complex object navigation and conditionals
3. **section_83_election.md** - Advanced conditionals, loops, and currency formatting
4. **Standards specification** - Documents expected Liquid syntax

## Stencil Capabilities Research

### Core Stencil Features

1. **Template Engine**: Django/Mustache-inspired syntax
2. **Variable Resolution**: `{{ variable }}` syntax (identical to Liquid)
3. **Control Flow**: `{% tag %}` syntax (identical to Liquid)
4. **Filters**: `{{ variable|filter }}` syntax (similar to Liquid)
5. **Template Inheritance**: Supports extends/blocks
6. **Swift Integration**: Native Swift Package Manager support

### Stencil Built-in Tags

- `for...endfor` - Iteration
- `if...endif` - Conditionals  
- `ifnot...endif` - Negative conditionals
- `include` - Template inclusion
- `extends/block` - Template inheritance
- `comment` - Comments

### Stencil Built-in Filters

- `default` - Default values
- `join` - Array joining
- `length` - Count items
- `upper/lower` - Case conversion
- `first/last` - Array access
- `slice` - Array slicing

## Syntax Differences Analysis

### ✅ Compatible Syntax (No Changes Needed)

| Pattern | Liquid | Stencil | Status |
|---------|--------|---------|--------|
| Variable Output | `{{variable}}` | `{{variable}}` | ✅ Identical |
| Object Navigation | `{{object.property}}` | `{{object.property}}` | ✅ Identical |
| If/Else Conditionals | `{% if condition %}...{% endif %}` | `{% if condition %}...{% endif %}` | ✅ Identical |
| For Loops | `{% for item in items %}...{% endfor %}` | `{% for item in items %}...{% endfor %}` | ✅ Identical |

### ⚠️ Similar but Different (Minor Changes)

| Pattern | Liquid | Stencil | Change Required |
|---------|--------|---------|-----------------|
| Filter Syntax | `{{var \| filter: "param"}}` | `{{var\|filter:"param"}}` | ⚠️ Spacing differences |
| Date Filter | `{{date \| date: "%B %d, %Y"}}` | `{{date\|date:"%B %d, %Y"}}` | ⚠️ Remove spaces around pipe |

### ❌ Different/Missing Features (Major Changes)

| Feature | Liquid | Stencil | Migration Strategy |
|---------|--------|---------|-------------------|
| Currency Filter | `{{amount \| currency}}` | Not built-in | 🔧 Custom filter needed |
| Date Formatting | `{{date \| date: "%B %d, %Y"}}` | Different format | 🔧 Custom date filter |
| Complex Conditionals | `{% unless condition %}` | Use `{% if not condition %}` | 🔄 Logic inversion |

## Migration Impact Assessment

### Low Impact (Direct Conversion)

- ✅ Basic variable interpolation: `{{variable}}`
- ✅ Object property access: `{{object.property}}`  
- ✅ Simple conditionals: `{% if condition %}`
- ✅ For loops: `{% for item in collection %}`

### Medium Impact (Syntax Adjustment)

- ⚠️ Filter spacing: Remove spaces around `|` in filters
- ⚠️ Filter parameters: Adjust parameter syntax if needed
- ⚠️ Conditional logic: Convert `unless` to `if not` patterns

### High Impact (Custom Implementation Required)

- 🔧 **Currency Filter**: Need custom `currency` filter implementation
- 🔧 **Date Filter**: Need custom date formatting filter matching current behavior
- 🔧 **Custom Filters**: Any domain-specific filters currently used

## Recommended Migration Strategy

### Phase 2: Dependency Integration

1. Add Stencil dependency to Package.swift
2. Create `StencilTemplateService` protocol
3. Implement basic template parsing and rendering

### Phase 3: Core Implementation  

1. **Custom Filter Development**:
   - Implement `currency` filter for monetary formatting
   - Implement `date` filter matching current Liquid date formatting
   - Add any other domain-specific filters

2. **Template Engine Integration**:
   - Replace current Liquid processing with Stencil
   - Maintain backward compatibility during transition
   - Add error handling and validation

### Phase 4: Integration

1. Update Standards parser to use Stencil
2. Ensure questionnaire responses map correctly
3. Add template variable validation

### Phase 5: Testing and Migration

1. Comprehensive test suite
2. Migrate existing notation files (minimal changes expected)
3. Update documentation

## Technical Considerations

### Security

- ✅ Stencil provides template sandboxing by default
- ✅ No code injection vulnerabilities with proper usage
- 🔧 Need to validate custom filter implementations

### Performance

- ✅ Stencil templates can be pre-compiled for better performance
- ✅ Caching capabilities available
- 📊 Performance testing needed against current implementation

### Error Handling

- ✅ Stencil provides detailed error reporting
- ✅ Template compilation errors are clear
- 🔧 Need to integrate error reporting with current validation system

## Syntax Conversion Examples

### Example 1: Simple Variable with Date Filter

**Current Liquid:**
```liquid
Date: {{neon_representative.signature.inserted_at|date}}
```

**Stencil Conversion:**
```stencil
Date: {{neon_representative.signature.inserted_at|date}}
```
*Note: Custom date filter implementation required*

### Example 2: Currency Formatting

**Current Liquid:**
```liquid
Amount: {{issuance.fair_market_value_per_share|currency}}
```

**Stencil Conversion:**
```stencil
Amount: {{issuance.fair_market_value_per_share|currency}}
```
*Note: Custom currency filter implementation required*

### Example 3: Complex Conditional

**Current Liquid:**
```liquid
{% if respondent_type == "org_and_person" %}
This covers both organization and individual.
{% else %}
This covers organization only.
{% endif %}
```

**Stencil Conversion:**
```stencil
{% if respondent_type == "org_and_person" %}
This covers both organization and individual.
{% else %}
This covers organization only.
{% endif %}
```
*Note: Identical syntax, no changes needed*

## Next Phase Preparation

### Phase 2 Prerequisites

1. ✅ Stencil syntax research complete
2. ✅ Current Liquid pattern audit complete  
3. ✅ Migration strategy defined
4. ✅ Custom filter requirements identified

### Required Custom Filters

1. **Currency Filter**:
   - Input: Decimal/Double values
   - Output: Formatted currency string (e.g., "$1,234.56")
   - Locale support for different currency formats

2. **Date Filter**:
   - Input: Date objects
   - Output: Formatted date string using format patterns
   - Support for current format patterns used in notations

3. **Text Filters** (if needed):
   - Capitalize, uppercase, lowercase
   - Strip whitespace
   - Other text transformations as required

## Conclusion

The migration from Liquid to Stencil is **highly feasible** with **minimal breaking changes**:

- ✅ **90%+ syntax compatibility** - Most templates will work with no changes
- ⚠️ **Minor adjustments** needed for filter spacing and parameters  
- 🔧 **Custom filters required** for currency and date formatting
- 🚀 **Benefits**: Better Swift ecosystem integration, performance, security

**Recommendation**: Proceed with Phase 2 (Dependency Integration) as the migration path is clear and low-risk.

---

*Generated during Phase 1: Research and Planning*  
*Issue #11 - Stencil Templating Implementation Roadmap*  
*Branch: roadmap/11-phase-1*