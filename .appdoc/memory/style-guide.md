# Documentation Style Guide

This style guide defines conventions for generated documentation to ensure consistency across the project.

## General Principles

1. **Clarity First**: Optimize for understanding, not brevity
2. **Active Voice**: Use action verbs and imperative mood
3. **Present Tense**: Describe what code does, not what it did
4. **Consistency**: Follow established patterns throughout documentation
5. **Accessibility**: Write for varying technical levels

## Tone and Voice

- **Professional but approachable**: Avoid overly casual language or excessive formality
- **Helpful and instructive**: Guide users through tasks
- **Confident but not arrogant**: State facts without being condescending
- **Concise**: Remove unnecessary words while maintaining clarity

## Formatting Standards

### Headings

- **ATX style** (# ## ###) preferred over Setext style (underlines)
- Use sentence case: "Getting started" not "Getting Started"
- No punctuation at end of headings
- Leave blank line before and after headings

### Code Blocks

- Always specify language for syntax highlighting
- Use triple backticks (```) for fenced code blocks
- Include context: what the code does and expected output
- Keep examples under 20 lines when possible
- Use inline code (`text`) for single identifiers or short expressions

### Lists

- Use hyphens (-) for unordered lists
- Use 1. 2. 3. for ordered lists (not 1) 2) 3))
- Capitalize first word of each list item
- End list items with period if they're complete sentences
- Maintain consistent indentation (2 spaces per level)

### Links

- Use inline links: [text](url)
- Descriptive link text: "See installation guide" not "click here"
- Verify links work before publishing
- Use relative links for internal documentation

### Tables

- Align columns with pipes
- Use header separator (|---|)
- Keep cell content concise
- Consider lists for simple 2-column data

## Code Documentation

### JSDoc/TSDoc Style

```typescript
/**
 * Brief description of what the function does.
 *
 * More detailed explanation if needed. Describe behavior,
 * constraints, or important implementation details.
 *
 * @param paramName - Description of parameter
 * @param anotherParam - Description with type info if not obvious
 * @returns Description of return value
 * @throws {ErrorType} When error occurs
 *
 * @example
 * ```typescript
 * const result = myFunction('input', 42);
 * console.log(result); // Expected output
 * ```
 */
function myFunction(paramName: string, anotherParam: number): ReturnType {
  // Implementation
}
```

### Python Docstring Style

```python
def my_function(param_name: str, another_param: int) -> ReturnType:
    """Brief description of what the function does.

    More detailed explanation if needed. Describe behavior,
    constraints, or important implementation details.

    Args:
        param_name: Description of parameter
        another_param: Description with type info if not obvious

    Returns:
        Description of return value

    Raises:
        ErrorType: When error occurs

    Example:
        >>> result = my_function('input', 42)
        >>> print(result)
        Expected output
    """
    pass
```

## README Structure

Standard section order:

1. Title + Badges
2. Description + Key Features
3. Table of Contents (for long READMEs)
4. Installation
5. Quick Start
6. Usage Examples
7. API Reference
8. Configuration
9. Examples
10. Testing
11. Contributing
12. Troubleshooting
13. Changelog Link
14. License
15. Acknowledgments

## API Documentation

### Endpoint Documentation

Structure for each API endpoint:

```markdown
### GET /api/users/:id

Retrieves a user by their unique identifier.

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `id` (string, required): User UUID

**Query Parameters**:
- `include` (string, optional): Comma-separated relations to include (e.g., "posts,comments")

**Response**: `200 OK`

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "email": "user@example.com",
  "name": "John Doe"
}
```

**Error Responses**:
- `404 Not Found`: User does not exist
- `401 Unauthorized`: Missing or invalid auth token
```

## Examples

### Good Example

```markdown
## Installation

Install the package using npm:

```bash
npm install AppDoc-framework
```

Or using yarn:

```bash
yarn add AppDoc-framework
```

## Quick Start

Create a new documentation project:

```typescript
import { AppDoc } from 'AppDoc-framework';

const writer = new AppDoc({
  agent: 'copilot',
  outputDir: 'docs'
});

await writer.analyze();
await writer.generateReadme();
```

This analyzes your codebase and generates a README.md file in the docs directory.
```

### Bad Example

```markdown
## Installation

Install it.

## Usage

Use it to generate docs.
```

## Common Patterns

### Describing Functions

**Template**:
```
[Function name] [primary action] [object/subject].

Additional details about behavior, constraints, or side effects.
```

**Examples**:
- "Creates a new user account with the provided email and password."
- "Validates input data against the schema and returns sanitized values."
- "Fetches user data from the database. Throws an error if user not found."

### Writing Installation Instructions

1. State prerequisites first
2. Show primary installation method
3. List alternatives if applicable
4. Verify installation with version check
5. Link to troubleshooting for common issues

### Configuration Documentation

1. Show example configuration first
2. Describe each option with type and default
3. Group related options
4. Explain when each option should be used
5. Warn about breaking or deprecated options

## Terminology

### Preferred Terms

- Use "function" not "method" for standalone functions
- Use "parameter" not "argument" in documentation
- Use "return" not "output" for function results
- Use "throw" not "raise" for exceptions in JavaScript/TypeScript
- Use "raise" not "throw" for exceptions in Python

### Avoid

- Gendered pronouns (use "they/their" or rephrase)
- Ableist language ("sanity check" → "verification")
- Violent metaphors ("kill process" → "terminate process")
- Jargon without explanation
- Unnecessary abbreviations

## Version History

When documenting changes:

- Use semantic versioning (MAJOR.MINOR.PATCH)
- Group changes by type: Added, Changed, Deprecated, Removed, Fixed, Security
- Link to relevant pull requests or issues
- Include migration guides for breaking changes

## Customization

This style guide can be customized per project. Add overrides between these markers:

<!-- STYLE_OVERRIDE_START -->
<!-- Project-specific style preferences go here -->
<!-- STYLE_OVERRIDE_END -->

---

**Version**: 1.0.0
**Last Updated**: 2025-11-11

