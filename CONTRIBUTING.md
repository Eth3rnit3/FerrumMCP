# Contributing to FerrumMCP

First off, thank you for considering contributing to FerrumMCP! It's people like you that make FerrumMCP such a great tool.

## Code of Conduct

This project and everyone participating in it is governed by common sense and mutual respect. By participating, you are expected to uphold this standard. Please report unacceptable behavior to [eth3rnit3@gmail.com](mailto:eth3rnit3@gmail.com).

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, please include as many details as possible:

**Use the bug report template** (see `.github/ISSUE_TEMPLATE/bug_report.md`)

Include:
- **Clear title**: Describe the bug in one sentence
- **Description**: What happened vs. what you expected
- **Steps to reproduce**: Numbered list of steps
- **Environment**: Ruby version, OS, browser version
- **Logs**: Relevant excerpts from `logs/ferrum_mcp.log`
- **Screenshots**: If applicable

**Example**:
```markdown
### Bug: Screenshot tool fails with large images

**Description**
The screenshot tool crashes when capturing pages with images larger than 10MB.

**Steps to Reproduce**
1. Create session: `create_session(headless: true)`
2. Navigate to: `navigate(url: "https://example.com/large-image", session_id: ...)`
3. Take screenshot: `screenshot(session_id: ...)`
4. Error occurs: "Image too large for base64 encoding"

**Expected Behavior**
Screenshot should be resized or paginated.

**Environment**
- Ruby: 3.3.5
- OS: macOS 14.1
- Chrome: 119.0.6045.199
- FerrumMCP: 0.1.0

**Logs**
```
ERROR -- : Screenshot failed: Image size exceeds limit
```
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

**Use the feature request template** (see `.github/ISSUE_TEMPLATE/feature_request.md`)

Include:
- **Clear title**: Describe the feature in one sentence
- **Problem**: What problem does this solve?
- **Solution**: Describe your proposed solution
- **Alternatives**: Other solutions you've considered
- **Use cases**: Real-world examples

### Pull Requests

We actively welcome your pull requests!

#### Before You Start

1. **Check existing issues**: See if someone is already working on it
2. **Open an issue first**: Discuss major changes before coding
3. **One feature per PR**: Keep PRs focused and manageable
4. **Follow the style guide**: Use RuboCop and existing patterns

#### Development Workflow

1. **Fork the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/FerrumMCP.git
   cd FerrumMCP
   ```

2. **Create a branch**
   ```bash
   git checkout -b feature/my-awesome-feature
   # or
   git checkout -b fix/my-bug-fix
   ```

   **Branch naming**:
   - `feature/` - New features
   - `fix/` - Bug fixes
   - `docs/` - Documentation changes
   - `refactor/` - Code refactoring
   - `test/` - Test improvements
   - `chore/` - Maintenance tasks

3. **Set up development environment**
   ```bash
   bundle install
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. **Make your changes**
   - Write clean, readable code
   - Follow Ruby best practices
   - Add tests for new functionality
   - Update documentation

5. **Run the linter**
   ```bash
   bundle exec rubocop
   # Auto-fix issues
   bundle exec rubocop -A
   ```

6. **Run the tests**
   ```bash
   bundle exec rspec
   # With coverage
   COVERAGE=true bundle exec rspec
   ```

7. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: Add awesome new feature"
   ```

   **Commit message format**:
   ```
   <type>: <subject>

   <body>

   <footer>
   ```

   **Types**:
   - `feat` - New feature
   - `fix` - Bug fix
   - `docs` - Documentation
   - `style` - Formatting, missing semicolons, etc.
   - `refactor` - Code restructuring
   - `test` - Adding tests
   - `chore` - Maintenance

   **Examples**:
   ```
   feat: Add rate limiting to HTTP transport

   - Implement token bucket algorithm
   - Add MAX_REQUESTS_PER_MINUTE configuration
   - Update docs with rate limit information

   Closes #123
   ```

   ```
   fix: Resolve screenshot encoding issue with large images

   Images larger than 10MB now automatically resize to fit
   within base64 encoding limits.

   Fixes #456
   ```

8. **Push to your fork**
   ```bash
   git push origin feature/my-awesome-feature
   ```

9. **Open a Pull Request**
   - Use the PR template (see `.github/PULL_REQUEST_TEMPLATE.md`)
   - Link related issues
   - Describe your changes
   - Add screenshots/examples if applicable

#### Pull Request Requirements

Your PR must meet these requirements:

✅ **Tests pass**: All RSpec tests must pass
✅ **Linter passes**: No RuboCop offenses
✅ **Coverage maintained**: Branch coverage ≥ 55%, line coverage ≥ 79%
✅ **Documentation updated**: README, CHANGELOG, or docs/ if needed
✅ **Zeitwerk check**: Autoloading must work (`bundle exec rake zeitwerk:check`)
✅ **Commit messages**: Follow conventional commit format
✅ **No merge commits**: Rebase on main before submitting

#### Code Review Process

1. **Automated checks**: GitHub Actions runs CI checks
2. **Maintainer review**: A maintainer will review your code
3. **Feedback**: Address any requested changes
4. **Approval**: Once approved, a maintainer will merge

**What we look for**:
- Code quality and readability
- Test coverage
- Documentation completeness
- Adherence to existing patterns
- Performance implications

## Development Guidelines

### Code Style

We use **RuboCop** for code style enforcement:

```bash
# Check for offenses
bundle exec rubocop

# Auto-fix (with caution)
bundle exec rubocop -A
```

**Key conventions**:
- 2 spaces for indentation (no tabs)
- `frozen_string_literal: true` at top of each file
- 120 character line length limit
- Snake_case for methods and variables
- CamelCase for classes and modules
- Double quotes for strings (unless single quotes avoid escaping)

### Testing

#### Writing Tests

- **File location**: `spec/ferrum_mcp/tools/my_tool_spec.rb`
- **File naming**: `*_spec.rb`
- **Test structure**: Use `describe` and `context` blocks

**Example**:
```ruby
# spec/ferrum_mcp/tools/my_tool_spec.rb
require 'spec_helper'

RSpec.describe FerrumMCP::Tools::MyTool do
  let(:session_manager) { instance_double(FerrumMCP::SessionManager) }
  let(:session) { instance_double(FerrumMCP::Session) }
  let(:browser) { instance_double(Ferrum::Browser) }
  let(:tool) { described_class.new(session_manager) }

  before do
    allow(session_manager).to receive(:with_session).and_yield(browser)
  end

  describe '#execute' do
    context 'when successful' do
      it 'returns success response' do
        result = tool.execute({ session_id: 'test-session', param: 'value' })
        expect(result[:success]).to be true
      end
    end

    context 'when error occurs' do
      it 'returns error response' do
        allow(browser).to receive(:goto).and_raise(StandardError, 'Test error')
        result = tool.execute({ session_id: 'test-session' })
        expect(result[:success]).to be false
      end
    end
  end
end
```

#### Running Tests

```bash
# All tests
bundle exec rspec

# Specific file
bundle exec rspec spec/ferrum_mcp/tools/my_tool_spec.rb

# Specific test
bundle exec rspec spec/ferrum_mcp/tools/my_tool_spec.rb:42

# With coverage
COVERAGE=true bundle exec rspec
```

#### Coverage Requirements

- **Minimum line coverage**: 79%
- **Minimum branch coverage**: 55%
- **New code**: Should maintain or improve coverage

### Adding New Tools

To add a new browser automation tool:

1. **Create tool file**: `lib/ferrum_mcp/tools/my_tool.rb`

```ruby
# frozen_string_literal: true

module FerrumMCP
  module Tools
    # MyTool does something awesome
    class MyTool < BaseTool
      def self.tool_name
        'my_tool'
      end

      def self.description
        'Does something awesome with the browser'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            },
            my_param: {
              type: 'string',
              description: 'Description of my parameter'
            }
          },
          required: ['session_id', 'my_param']
        }
      end

      def execute(params)
        session_id = params[:session_id]
        my_param = params[:my_param]

        session_manager.with_session(session_id) do |browser|
          # Your logic here
          result = browser.do_something(my_param)
          success_response({ result: result })
        end
      rescue StandardError => e
        error_response("Failed to do something: #{e.message}")
      end
    end
  end
end
```

2. **Register in server**: Add to `TOOL_CLASSES` in `lib/ferrum_mcp/server.rb`

```ruby
TOOL_CLASSES = [
  # ... existing tools ...
  Tools::MyTool
].freeze
```

3. **Write tests**: Create `spec/ferrum_mcp/tools/my_tool_spec.rb`

4. **Update documentation**:
   - Add to [docs/API_REFERENCE.md](docs/API_REFERENCE.md)
   - Update CHANGELOG.md under `[Unreleased]`

### Documentation

Documentation is as important as code!

**What to document**:
- Public APIs and methods
- Complex algorithms
- Non-obvious behavior
- Configuration options
- Breaking changes

**Where to document**:
- Inline comments for complex code
- [docs/API_REFERENCE.md](docs/API_REFERENCE.md) for tools
- [CHANGELOG.md](CHANGELOG.md) for changes
- README.md for user-facing features

**Example inline documentation**:
```ruby
# Find element with retry logic for stale elements.
#
# Chrome can mark elements as stale if the page is modified
# during interaction. We retry up to 3 times to handle this.
#
# @param selector [String] CSS or XPath selector
# @param timeout [Integer] Timeout in seconds
# @return [Ferrum::Element] Found element
# @raise [ToolError] if element not found after retries
def find_element(browser, selector, timeout: 5)
  # implementation...
end
```

### Architecture

Understand the architecture before contributing:

```
FerrumMCP/
├── Server (MCP Server)
│   ├── SessionManager (Thread-safe session pool)
│   │   └── Session (Browser wrapper)
│   │       └── BrowserManager (Ferrum lifecycle)
│   ├── ResourceManager (MCP Resources)
│   └── Tools (27+ automation tools)
└── Transport (HTTP or STDIO)
```

**Key principles**:
1. **Session-based**: All operations require a session
2. **Thread-safe**: Use mutexes for shared state
3. **Tool isolation**: Each tool is independent
4. **Error handling**: Always catch and report errors
5. **Resource cleanup**: Close sessions and browsers

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.

## Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and general discussion
- **Pull Requests**: Code contributions
- **Email**: [eth3rnit3@gmail.com](mailto:eth3rnit3@gmail.com) for sensitive issues

### Getting Help

- **Read the docs**: Start with [docs/](docs/)
- **Search issues**: Someone may have asked already
- **Ask a question**: Open a GitHub Discussion
- **Be specific**: Provide context and examples

### Recognition

Contributors are recognized in:
- CHANGELOG.md for significant contributions
- README.md contributors section
- Release notes
- GitHub contributors page

## Release Process

(For maintainers only)

1. Update version in `lib/ferrum_mcp/version.rb`
2. Update CHANGELOG.md with release date
3. Commit: `chore: Release v1.0.0`
4. Tag: `git tag -a v1.0.0 -m "Release v1.0.0"`
5. Push: `git push && git push --tags`
6. GitHub Actions builds and publishes Docker image
7. Create GitHub Release from tag
8. (Future) Publish gem to RubyGems.org

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

Don't hesitate to ask! We're here to help:

- Open a [GitHub Discussion](https://github.com/Eth3rnit3/FerrumMCP/discussions)
- Email: [eth3rnit3@gmail.com](mailto:eth3rnit3@gmail.com)

Thank you for contributing to FerrumMCP! 🎉
