# Contributing to SimpleTimeService

Thank you for your interest in contributing to SimpleTimeService!

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with:
- Clear description of the issue
- Steps to reproduce
- Expected behavior
- Actual behavior
- Environment details (OS, versions, etc.)
- Relevant logs or screenshots

### Suggesting Enhancements

For feature requests or enhancements:
- Check if it's already been suggested
- Provide clear use case
- Explain expected behavior
- Consider implementation details

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```

3. **Make your changes**
   - Write clean, readable code
   - Follow existing code style
   - Add tests for new functionality
   - Update documentation

4. **Test your changes**
   ```bash
   # Run tests
   cd app
   go test -v ./...
   
   # Build Docker image
   docker build -t simpletimeservice:test .
   
   # Test locally
   docker run -p 8080:8080 simpletimeservice:test
   ```

5. **Commit your changes**
   ```bash
   git commit -m "feat: add amazing feature"
   ```
   
   Use conventional commits:
   - `feat:` new feature
   - `fix:` bug fix
   - `docs:` documentation
   - `style:` formatting
   - `refactor:` code restructuring
   - `test:` adding tests
   - `chore:` maintenance

6. **Push to your fork**
   ```bash
   git push origin feature/amazing-feature
   ```

7. **Create Pull Request**
   - Provide clear description
   - Reference any related issues
   - Include screenshots if applicable
   - Ensure CI passes

## Development Guidelines

### Code Style

**Go Code:**
- Follow official Go style guide
- Run `gofmt` before committing
- Use meaningful variable names
- Add comments for complex logic
- Keep functions small and focused

**Terraform:**
- Use consistent naming
- Add descriptions to variables
- Use modules for reusability
- Format with `terraform fmt`

**Kubernetes:**
- Follow K8s best practices
- Use meaningful labels
- Set resource limits
- Include health checks

### Testing

- Write unit tests for new code
- Maintain >80% code coverage
- Test error conditions
- Add integration tests where appropriate

### Documentation

- Update README for new features
- Add inline comments for complex code
- Update relevant docs in `docs/`
- Include examples

### Security

- Never commit secrets
- Use environment variables
- Follow security best practices
- Run security scans locally

## Project Structure

```
devops-challenge-solution/
├── app/                 # Go application
├── terraform/          # Infrastructure as Code
├── kubernetes/         # K8s manifests
├── scripts/            # Helper scripts
├── docs/               # Documentation
└── .github/            # CI/CD workflows
```

## Getting Help

- Check existing issues and PRs
- Review documentation
- Ask questions in issues
- Contact: careers@particle41.com

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism
- Focus on what's best for the project

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

