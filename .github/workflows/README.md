# GitHub Workflow for K8s Lab PowerShell Testing

This directory contains GitHub Actions workflows for testing the PowerShell K8s Lab setup.

## Workflows

### 1. test-powershell-lab-simple.yml

A streamlined workflow that focuses on essential testing without requiring actual cluster creation.

**What it tests:**

- PowerShell script syntax validation
- Basic command functionality (help, status, error handling)
- File structure validation
- Demo application YAML syntax
- Comprehensive test suite execution

**Triggers:**

- Push to `main` or `develop` branches
- Pull requests to `main` branch
- Manual dispatch with test type selection

**Test Types:**

- `syntax` - Basic syntax validation only
- `basic` - Syntax + basic commands + dependencies (default)
- `full` - All tests including cluster operations (for local use)

### 2. test-powershell-lab.yml (Disabled)

A comprehensive workflow that includes actual cluster testing (currently disabled for CI due to resource constraints).

**Features:**

- Full Minikube and Kind cluster testing
- Multi-node cluster validation
- Performance benchmarking
- Advanced demo deployment testing
- Comprehensive reporting

## Usage

### Running Tests Locally

```powershell
# Run basic syntax validation
.\test-lab.ps1 -TestType syntax

# Run basic functionality tests
.\test-lab.ps1 -TestType basic

# Run full tests including cluster operations
.\test-lab.ps1 -TestType full -Environment minikube
```

### Triggering GitHub Actions

1. **Automatic Triggers:**
   - Push commits to `main` or `develop` branches
   - Create pull requests targeting `main`

2. **Manual Triggers:**
   - Go to Actions tab in GitHub repository
   - Select "Test PowerShell K8s Lab"
   - Click "Run workflow"
   - Choose test type (syntax/basic/full)

## Test Coverage

### Script Validation
- ✅ PowerShell syntax checking
- ✅ Main script (k8s-lab.ps1)
- ✅ Setup scripts (setup-minikube.ps1, setup-kind.ps1)
- ✅ Error handling validation

### Functionality Testing
- ✅ Help command output
- ✅ Status command execution
- ✅ Error handling for invalid commands
- ✅ File structure validation
- ✅ Demo YAML syntax validation

### Dependency Validation
- ✅ PowerShell version compatibility
- ✅ Docker availability
- ✅ Minikube installation (when available)
- ✅ Kind installation (when available)
- ✅ kubectl availability

### Advanced Testing (local only)
- 🔄 Minikube cluster creation and management
- 🔄 Kind cluster creation and management
- 🔄 Multi-node cluster validation
- 🔄 Demo application deployment
- 🔄 Performance benchmarking

## Artifacts

Each workflow run generates:
- **Test Report**: Detailed markdown report with test results
- **Logs**: Complete execution logs for debugging
- **Retention**: Artifacts kept for 30 days

## Environment Requirements

### GitHub Actions Runner
- Windows Latest
- PowerShell 7.x
- Docker Desktop (for cluster testing)

### Local Testing
- Windows 10/11 or Windows Server
- PowerShell 5.1+ (PowerShell 7.x recommended)
- Docker Desktop (for cluster operations)
- Minikube (optional)
- Kind (optional)
- kubectl (optional)

## Configuration

### Workflow Customization

You can customize the workflows by modifying:

```yaml
env:
  MINIKUBE_VERSION: 'v1.33.1'
  KIND_VERSION: 'v0.20.0'
  KUBECTL_VERSION: 'v1.30.0'
```

### Test Configuration

Modify test behavior in `test-lab.ps1`:

```powershell
# Change default test type
[string]$TestType = 'basic'

# Change default environment
[string]$Environment = 'minikube'
```

## Troubleshooting

### Common Issues

1. **Docker not available in CI**
   - Expected for syntax/basic tests
   - Full cluster tests require Docker Desktop

2. **PowerShell script execution policy**
   - CI automatically sets appropriate execution policy
   - Local testing may require: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

3. **Path issues**
   - Ensure scripts are run from the k8s-lab root directory
   - Use absolute paths when necessary

4. **"Unable to resolve action actions/setup-powershell@v1" error**
   - This action doesn't exist - PowerShell is pre-installed on Windows runners
   - The workflow has been fixed to use built-in PowerShell capabilities
   - Use `shell: pwsh` instead of trying to setup PowerShell

### Debugging Failed Tests

1. Check the workflow logs in GitHub Actions
2. Download the test report artifact
3. Run tests locally with verbose output:
   ```powershell
   .\test-lab.ps1 -TestType full -Environment minikube -Verbose
   ```

## Contributing

When adding new tests:

1. Update the test script (`test-lab.ps1`)
2. Add corresponding workflow steps if needed
3. Update this README
4. Test locally before submitting PR

## Security Considerations

- Workflows run in isolated GitHub-hosted runners
- No sensitive data is stored in artifacts
- Docker operations are containerized
- Cleanup steps ensure no persistent resources

---

*This testing framework ensures the reliability and compatibility of the K8s Lab PowerShell scripts across different environments and scenarios.*
