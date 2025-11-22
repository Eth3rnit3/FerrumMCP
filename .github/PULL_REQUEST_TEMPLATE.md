# Pull Request

## Description

**What does this PR do?**

A clear and concise description of the changes.

Fixes #(issue number)

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Code refactoring
- [ ] Tests
- [ ] CI/CD
- [ ] Other (please describe):

## Changes Made

**Detailed list of changes**

- Change 1
- Change 2
- Change 3

## Testing

**How has this been tested?**

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing performed
- [ ] All tests pass locally

**Test Configuration**:
- Ruby version: (e.g., 3.3.5)
- OS: (e.g., macOS 14.1)
- Browser: (e.g., Chrome 119)

**Test scenarios covered**:
1. Scenario 1: [description]
2. Scenario 2: [description]

## Documentation

- [ ] Updated API_REFERENCE.md (if adding/changing tools)
- [ ] Updated CHANGELOG.md under `[Unreleased]`
- [ ] Updated README.md (if needed)
- [ ] Updated Configuration docs (if adding env vars)
- [ ] Added inline code documentation
- [ ] No documentation changes needed

## Checklist

**Before submitting, ensure you have:**

- [ ] Read [CONTRIBUTING.md](../CONTRIBUTING.md)
- [ ] Followed the code style (RuboCop passes: `bundle exec rubocop`)
- [ ] Added tests that prove the fix/feature works
- [ ] All tests pass (`bundle exec rspec`)
- [ ] Zeitwerk check passes (`bundle exec rake zeitwerk:check`)
- [ ] Coverage maintained or improved (≥79% line, ≥55% branch)
- [ ] Commit messages follow [conventional commits](https://www.conventionalcommits.org/)
- [ ] Updated documentation
- [ ] No merge commits (rebased on main)

## Breaking Changes

**Does this PR introduce breaking changes?**

- [ ] Yes (describe below)
- [ ] No

**If yes, describe the breaking changes and migration path**:

## Screenshots

**If applicable, add screenshots to demonstrate the changes**

## Performance Impact

**Does this change affect performance?**

- [ ] Improves performance
- [ ] Degrades performance (explain why acceptable)
- [ ] No performance impact

**Benchmarks** (if applicable):
```
Before: X ops/sec
After: Y ops/sec
```

## Additional Notes

**Anything else reviewers should know?**

- Dependencies added/updated
- Configuration changes required
- Known limitations
- Future improvements planned

## Reviewer Checklist

*For maintainers reviewing this PR*

- [ ] Code quality is acceptable
- [ ] Tests are adequate
- [ ] Documentation is complete
- [ ] No security concerns
- [ ] Performance is acceptable
- [ ] Breaking changes are justified and documented
