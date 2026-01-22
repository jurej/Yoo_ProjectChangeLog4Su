# Code Quality Check Scripts

These scripts help verify that the plugin meets SketchUp Extension Warehouse requirements using [rubocop-sketchup](https://github.com/SketchUp/rubocop-sketchup).

## Prerequisites

- Ruby installed (2.7+ recommended)
- RubyGems available

## Usage

### Windows (PowerShell)
```powershell
.\scripts\check_release.ps1
```

### Linux/macOS (Bash)
```bash
chmod +x scripts/check_release.sh
./scripts/check_release.sh
```

### Manual Installation and Run

If you prefer to install manually:

```bash
# Install rubocop and rubocop-sketchup
gem install rubocop rubocop-sketchup

# Run basic check
rubocop --format simple

# Generate Extension Review HTML report
rubocop -f extension_review -o report.html
```

## What Gets Checked

The rubocop-sketchup tool checks for:

- **SketchupRequirements**: Extension Warehouse technical requirements
- **SketchupDeprecations**: Use of deprecated SketchUp API methods
- **SketchupPerformance**: Performance issues and anti-patterns
- **SketchupSuggestions**: Best practices and recommendations
- **SketchupBugs**: Common bugs and pitfalls

## Reports

After running, you'll get:
- Console output with issues found
- `report.html` - Detailed Extension Review report (if generated)
- `rubocop.json` - JSON format report (if generated)

## GitHub Actions

This repository also includes a GitHub Actions workflow (`.github/workflows/rubocop.yml`) that automatically runs these checks on every push and pull request.
