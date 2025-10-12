# Contributing to ProxBalance

Thank you for your interest in contributing to ProxBalance! This document provides guidelines and instructions for contributing.

---

## 🎯 Ways to Contribute

There are many ways to contribute to ProxBalance:

- 🐛 **Report bugs** - Help us identify and fix issues
- 💡 **Suggest features** - Share ideas for improvements
- 📖 **Improve documentation** - Make it easier for others to use ProxBalance
- 🔧 **Submit code** - Fix bugs or implement new features
- 🧪 **Test** - Try ProxBalance in different environments
- 💬 **Help others** - Answer questions in Discussions
- ⭐ **Spread the word** - Share ProxBalance with the community

---

## 🐛 Reporting Bugs

### Before Submitting a Bug Report

1. **Check existing issues** - Someone may have already reported it
2. **Try the latest version** - The bug might already be fixed
3. **Check troubleshooting guide** - See if there's a known solution
4. **Gather information** - Collect logs and system details

### How to Submit a Good Bug Report

Include the following information:

```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '...'
3. See error

**Expected behavior**
What you expected to happen.

**Environment:**
- Proxmox VE version: [e.g., 8.1]
- ProxBalance version: [e.g., 1.0.0]
- Container config: [CPU/RAM/Storage]
- Number of nodes: [e.g., 4]
- Number of guests: [e.g., 50]

**Logs:**
```
Paste relevant logs here
```

**Additional context**
Any other information that might be helpful.
```

[Submit Bug Report →](https://github.com/Pr0zak/ProxBalance/issues/new?labels=bug)

---

## 💡 Suggesting Features

We love feature suggestions! Here's how to submit a great one:

### Before Submitting

1. **Check existing features** - It might already exist
2. **Check planned features** - See [CHANGELOG.md](CHANGELOG.md) for roadmap
3. **Search discussions** - Someone might have suggested it already

### How to Submit a Feature Request

Use this template:

```markdown
**Is your feature request related to a problem?**
A clear description of what the problem is. Ex. I'm always frustrated when [...]

**Describe the solution you'd like**
A clear description of what you want to happen.

**Describe alternatives you've considered**
Other solutions or features you've considered.

**Use case**
Describe your specific use case and how this would help.

**Additional context**
Add any other context, mockups, or examples.
```

[Submit Feature Request →](https://github.com/Pr0zak/ProxBalance/issues/new?labels=enhancement)

---

## 🔧 Contributing Code

### Getting Started

1. **Fork the repository**
   ```bash
   # Click "Fork" on GitHub
   ```

2. **Clone your fork**
   ```bash
   git clone https://github.com/YOUR-USERNAME/ProxBalance.git
   cd ProxBalance
   ```

3. **Create a branch**
   ```bash
   git checkout -b feature/amazing-feature
   # or
   git checkout -b fix/bug-description
   ```

4. **Set up development environment**
   ```bash
   # Install dependencies
   python3 -m venv venv
   source venv/bin/activate
   pip install flask flask-cors gunicorn
   
   # For testing
   pip install pytest black flake8
   ```

### Development Guidelines

#### Code Style

- **Python**: Follow PEP 8 style guide
  ```bash
  # Format code
  black *.py
  
  # Check style
  flake8 *.py
  ```

- **JavaScript/React**: Use consistent formatting
  ```bash
  # Use 2 spaces for indentation
  # Use semicolons
  # Use meaningful variable names
  ```

- **Bash**: Follow Google Shell Style Guide
  ```bash
  # Use 2 spaces for indentation
  # Quote variables: "$variable"
  # Use meaningful function names
  ```

#### Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```bash
git commit -m "feat(api): add webhook support for migration events"
git commit -m "fix(collector): handle missing SSH keys gracefully"
git commit -m "docs(readme): add troubleshooting section for 502 errors"
```

#### Testing

Before submitting:

```bash
# Test Python code
python3 collector.py
python3 app.py

# Test installer script
./install.sh  # In a test environment

# Check for errors
journalctl -u proxmox-balance -n 50
```

### Submitting Changes

1. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add amazing feature"
   ```

2. **Push to your fork**
   ```bash
   git push origin feature/amazing-feature
   ```

3. **Create Pull Request**
   - Go to the original repository
   - Click "New Pull Request"
   - Select your branch
   - Fill out the PR template

### Pull Request Guidelines

A good PR should:

- ✅ Have a clear title and description
- ✅ Reference any related issues
- ✅ Include tests if applicable
- ✅ Update documentation if needed
- ✅ Follow the code style guidelines
- ✅ Have meaningful commit messages
- ✅ Be focused on a single feature/fix

**PR Template:**

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Related Issues
Fixes #123

## Testing
Describe how you tested this

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-reviewed the code
- [ ] Commented complex code
- [ ] Updated documentation
- [ ] No new warnings
- [ ] Added tests (if applicable)
```

---

## 📖 Improving Documentation

Documentation improvements are always welcome!

### What Needs Documentation

- Installation steps
- Configuration options
- API endpoints
- Usage examples
- Troubleshooting tips
- Best practices
- Architecture details

### How to Contribute

1. Fork the repository
2. Edit the relevant `.md` file
3. Submit a pull request

**Documentation Guidelines:**

- Use clear, simple language
- Include code examples
- Add screenshots where helpful
- Keep formatting consistent
- Test all commands and links
- Use proper markdown syntax

---

## 🧪 Testing

Help us test ProxBalance in different environments:

### Test Scenarios

- Different Proxmox versions (7.x, 8.x)
- Various cluster sizes (small, medium, large)
- Different network configurations
- Edge cases (no guests, single node, etc.)
- Migration scenarios
- Tag configurations

### Reporting Test Results

Share your testing results in [Discussions](https://github.com/Pr0zak/ProxBalance/discussions):

```markdown
**Environment:**
- Proxmox VE: 8.1
- Nodes: 4
- Guests: 50 (40 CT, 10 VM)

**Test Performed:**
- Installed ProxBalance
- Configured anti-affinity tags
- Executed 10 migrations

**Results:**
All migrations successful. UI responsive. No errors in logs.

**Notes:**
Installation took 4 minutes. Everything worked as expected.
```

---

## 💬 Community Guidelines

### Code of Conduct

We are committed to providing a welcoming and inclusive environment:

- ✅ Be respectful and considerate
- ✅ Welcome newcomers
- ✅ Focus on what's best for the community
- ✅ Show empathy towards others
- ❌ No harassment or discrimination
- ❌ No trolling or insulting comments
- ❌ No spam or self-promotion

### Communication Channels

- **GitHub Issues** - Bug reports and feature requests
- **GitHub Discussions** - General questions and discussions
- **Pull Requests** - Code contributions

### Getting Help

If you need help contributing:

1. Check existing documentation
2. Search closed issues and PRs
3. Ask in [Discussions](https://github.com/Pr0zak/ProxBalance/discussions)
4. Be patient and respectful

---

## 🏆 Recognition

Contributors will be:

- Listed in release notes
- Mentioned in the README (for significant contributions)
- Thanked in commit messages
- Appreciated by the community! 🎉

---

## 📋 Checklist for Contributions

Before submitting, ensure:

- [ ] Code follows project style
- [ ] Commits follow convention
- [ ] Documentation is updated
- [ ] Tests pass (if applicable)
- [ ] No merge conflicts
- [ ] PR description is clear
- [ ] Related issues are linked

---

## ❓ Questions?

If you have questions about contributing:

- 💬 Start a [Discussion](https://github.com/Pr0zak/ProxBalance/discussions)
- 📖 Read the [README](README.md)
- 🐛 Check existing [Issues](https://github.com/Pr0zak/ProxBalance/issues)

---

## 🙏 Thank You!

Your contributions help make ProxBalance better for everyone. Whether it's a bug report, feature suggestion, or code contribution - thank you for being part of the ProxBalance community!

---

**Happy Contributing! 🚀**

[⬆ Back to README](README.md)
