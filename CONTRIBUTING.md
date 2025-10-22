# Contributing to AppDoc

Thank you for your interest in contributing to AppDoc! We welcome contributions from the community and are grateful for your help in making this project better.

## Code of Conduct

This project adheres to our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How to Contribute

### Development Workflow

1. **Fork the repository** and clone your fork locally.
2. **Create a feature branch** from `main` (or `master`) for your changes.
3. **Set up the development environment**:
   ```bash
   pip install -r requirements.txt -r requirements-dev.txt
   pre-commit install
   ```
4. **Make your changes** following our coding standards.
5. **Add tests** for new functionality and ensure existing tests pass.
6. **Update documentation** if needed (README, docs/, etc.).
7. **Run quality checks**:
   ```bash
   black src/
   isort src/
   pre-commit run --all-files
   mkdocs build  # Check docs build
   ```
8. **Test your changes** on a sample codebase.
9. **Submit a pull request** with a clear description of your changes.

### Types of Contributions

- **Bug fixes**: Fix reported issues
- **New language analyzers**: Add support for additional programming languages
- **Documentation improvements**: Improve docs, add examples, fix typos
- **Tests**: Add new tests or improve test coverage
- **Performance optimizations**: Improve analysis speed or reduce memory usage
- **Feature requests**: Propose and implement new features

### Adding New Language Analyzers

If you're adding support for a new language:

1. Create `src/appdoc/analyzers/newlang_analyzer.py`
2. Implement the `BaseAnalyzer` interface
3. Add the analyzer to `src/appdoc/analyzers/__init__.py`
4. Update language mappings as needed
5. Add comprehensive tests
6. Update documentation in README and docs/

### Coding Standards

- Use type hints where possible
- Write docstrings for all public functions and classes
- Follow PEP 8 style guidelines
- Use `black` for code formatting
- Use `isort` for import sorting
- Write clear, descriptive commit messages (see below)

### Commit Message Guidelines

We follow [Conventional Commits](https://conventionalcommits.org/) for commit messages:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting, missing semicolons, etc.
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks, dependencies

Examples:
```
feat(js-analyzer): Add JSDoc comment extraction
fix(cli): Handle empty directory input gracefully
docs(readme): Update installation instructions
```

### Testing

- Add unit tests for new functionality in `tests/`
- Ensure all existing tests pass
- Test on multiple Python versions if possible
- Include integration tests for end-to-end functionality

### Documentation

- Update README.md for new features or changes
- Add examples to the documentation
- Ensure MkDocs builds successfully
- Test example code to ensure it works

### Issue Reporting

- Use the [issue template](.github/ISSUE_TEMPLATE.md) when reporting bugs
- Provide clear reproduction steps
- Include relevant system information (OS, Python version, etc.)
- Check for duplicate issues before reporting

### Pull Request Process

1. **Link to an issue** if applicable
2. **Describe your changes** clearly in the PR description
3. **Reference any related docs** or discussions
4. **Ensure CI checks pass**
5. **Request review** from maintainers

### Getting Help

- Reach out in GitHub Discussions for questions
- Check existing issues for similar problems
- Read the documentation at https://hewhoroams.github.io/AppDoc/

Thank you for contributing to AppDoc! 🚀
