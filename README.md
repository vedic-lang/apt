# Vedic APT Repository Integration Guide

## Overview
This guide integrates APT repository hosting into your existing Vedic CI/CD pipeline. The APT repo will be hosted on GitHub Pages at `https://vedic-lang.github.io/apt/`

## Step 1: Create APT Repository

Create a new repository named `apt` in the `vedic-lang` organization:
```bash
# Create new repo on GitHub: vedic-lang/apt
git clone https://github.com/vedic-lang/apt.git
cd apt
```

## Step 2: Generate GPG Key for Signing

```bash
# Generate GPG key (do this locally, not in CI)
gpg --full-generate-key
# Select: RSA and RSA, 4096 bits, no expiration
# Use: Vedic Language Team <your-email@example.com>

# Get your key ID
gpg --list-keys --keyid-format LONG
# Look for: pub   rsa4096/YOUR_KEY_ID

# Export public key
gpg --armor --export YOUR_KEY_ID > public.key

# Export private key (keep this secure!)
gpg --armor --export-secret-keys YOUR_KEY_ID > private.key
```

## Step 3: Add GPG Key to GitHub Secrets

1. Go to your **vedic** repository settings
2. Navigate to **Secrets and variables** → **Actions**
3. Add these secrets:
   - `GPG_PRIVATE_KEY`: Content of `private.key`
   - `GPG_PASSPHRASE`: Your GPG key passphrase (if set)
   - `APT_REPO_TOKEN`: GitHub Personal Access Token with `repo` scope for pushing to apt repo

## Step 4: Set Up APT Repository Structure

In your `apt` repository:

```bash
# Create initial structure
mkdir -p conf

# Create conf/distributions
cat > conf/distributions << 'EOF'
Origin: Vedic Language Team
Label: Vedic APT Repository
Codename: stable
Architectures: amd64 arm64 armhf i386
Components: main
Description: Official APT repository for Vedic programming language
SignWith: yes
EOF

# Create conf/options
cat > conf/options << 'EOF'
verbose
basedir .
EOF

# Create README
cat > README.md << 'EOF'
# Vedic APT Repository

Official Debian/Ubuntu package repository for the Vedic programming language.

## Installation

```bash
# Download and add the GPG key
curl -fsSL https://vedic-lang.github.io/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/vedic.gpg

# Add the repository
echo "deb [signed-by=/usr/share/keyrings/vedic.gpg] https://vedic-lang.github.io/apt stable main" | sudo tee /etc/apt/sources.list.d/vedic.list

# Update and install
sudo apt update
sudo apt install vedic
```

## Available Packages

- **vedic** - The Vedic programming language compiler and runtime

## Verify Installation

```bash
vedic --version
```
EOF

# Create index.html
cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Vedic APT Repository</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            line-height: 1.6;
            color: #333;
        }
        h1 { color: #2c3e50; }
        h2 { color: #34495e; margin-top: 30px; }
        code {
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }
        pre {
            background: #2c3e50;
            color: #ecf0f1;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
        }
        pre code {
            background: none;
            color: inherit;
            padding: 0;
        }
        .link { color: #3498db; text-decoration: none; }
        .link:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <h1>🕉️ Vedic APT Repository</h1>
    <p>Official Debian/Ubuntu package repository for the <a href="https://vedic-lang.github.io/" class="link">Vedic programming language</a>.</p>
    
    <h2>Quick Install</h2>
    <pre><code># Download and add the GPG key
curl -fsSL https://vedic-lang.github.io/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/vedic.gpg

# Add the repository
echo "deb [signed-by=/usr/share/keyrings/vedic.gpg] https://vedic-lang.github.io/apt stable main" | sudo tee /etc/apt/sources.list.d/vedic.list

# Update and install
sudo apt update
sudo apt install vedic</code></pre>

    <h2>Verify Installation</h2>
    <pre><code>vedic --version</code></pre>

    <h2>Available Packages</h2>
    <ul>
        <li><strong>vedic</strong> - The Vedic programming language compiler and runtime (x86_64, aarch64, armv7, i686)</li>
    </ul>

    <h2>Resources</h2>
    <ul>
        <li><a href="https://vedic-lang.github.io/" class="link">Official Website</a></li>
        <li><a href="https://github.com/vedic-lang/vedic" class="link">GitHub Repository</a></li>
        <li><a href="dists/stable/main/binary-amd64/Packages" class="link">Package List</a></li>
    </ul>
</body>
</html>
EOF

# Commit and push
git add .
git commit -m "Initial APT repository setup"
git push origin main
```

## Step 5: Enable GitHub Pages

1. Go to `vedic-lang/apt` repository settings
2. Click **Pages**
3. Select **Source**: `main` branch
4. Click **Save**

## Step 6: Update Release Workflow

Add this new job to your `.github/workflows/Release_CICD.yml`:

```yaml
    Publish-APT-Repository:
        needs: [Build-Linux]
        runs-on: ubuntu-latest
        
        steps:
            - name: Checkout apt repository
              uses: actions/checkout@v5
              with:
                  repository: vedic-lang/apt
                  token: ${{ secrets.APT_REPO_TOKEN }}
                  path: apt-repo
            
            - name: Download Linux release
              uses: actions/download-artifact@v5
              with:
                  name: linux
                  path: release_linux
            
            - name: Install reprepro
              run: |
                  sudo apt update
                  sudo apt install -y reprepro gnupg
            
            - name: Import GPG key
              run: |
                  echo "${{ secrets.GPG_PRIVATE_KEY }}" | gpg --import
                  echo "${{ secrets.GPG_PASSPHRASE }}" | gpg --batch --yes --passphrase-fd 0 --quick-add-key $(gpg --list-keys --keyid-format LONG | grep pub | head -1 | awk '{print $2}' | cut -d'/' -f2) rsa4096 sign 1y
            
            - name: Add Debian package to repository
              working-directory: apt-repo
              run: |
                  # Import the .deb file
                  reprepro includedeb stable ../release_linux/vedic-linux-x86_64.deb
                  
                  # List packages to verify
                  reprepro list stable
            
            - name: Commit and push changes
              working-directory: apt-repo
              run: |
                  git config user.name "GitHub Actions"
                  git config user.email "actions@github.com"
                  git add .
                  git commit -m "Update Vedic ${{ github.event.inputs.vesion }}" || echo "No changes to commit"
                  git push
```

## Step 7: Alternative - Standalone APT Publishing Workflow

Create `.github/workflows/Update_APT.yml` for manual APT updates:

```yaml
name: Update APT Repository

on:
    workflow_dispatch:
        inputs:
            version:
                description: 'Vedic version to publish'
                required: true
            deb_url:
                description: 'Direct URL to .deb file'
                required: true

jobs:
    update-apt:
        runs-on: ubuntu-latest
        
        steps:
            - name: Checkout apt repository
              uses: actions/checkout@v5
              with:
                  repository: vedic-lang/apt
                  token: ${{ secrets.APT_REPO_TOKEN }}
            
            - name: Install dependencies
              run: |
                  sudo apt update
                  sudo apt install -y reprepro gnupg wget
            
            - name: Import GPG key
              run: |
                  echo "${{ secrets.GPG_PRIVATE_KEY }}" | gpg --import
            
            - name: Download Debian package
              run: |
                  wget -O vedic.deb "${{ github.event.inputs.deb_url }}"
            
            - name: Add package to repository
              run: |
                  reprepro includedeb stable vedic.deb
                  reprepro list stable
            
            - name: Commit and push
              run: |
                  git config user.name "GitHub Actions"
                  git config user.email "actions@github.com"
                  git add .
                  git commit -m "Add Vedic v${{ github.event.inputs.version }}"
                  git push
```

## Step 8: Update Installation Script

Add APT installation option to your `install.sh`:

```bash
# Add this section before the curl download section

# Check if running on Debian/Ubuntu
if command -v apt-get >/dev/null 2>&1; then
    info "Detected Debian/Ubuntu system"
    echo "Would you like to install via APT repository? [y/N]"
    read -r response
    
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        info "Installing via APT repository..."
        
        # Add GPG key
        curl -fsSL https://vedic-lang.github.io/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/vedic.gpg
        
        # Add repository
        echo "deb [signed-by=/usr/share/keyrings/vedic.gpg] https://vedic-lang.github.io/apt stable main" | sudo tee /etc/apt/sources.list.d/vedic.list
        
        # Install
        sudo apt update
        sudo apt install -y vedic
        
        success "vedic installed successfully via APT!"
        echo "Run 'vedic --help' to get started"
        exit 0
    fi
fi
```

## Step 9: Testing the Setup

After setting up:

1. **Test locally**:
```bash
# Add your test system
curl -fsSL https://vedic-lang.github.io/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/vedic.gpg
echo "deb [signed-by=/usr/share/keyrings/vedic.gpg] https://vedic-lang.github.io/apt stable main" | sudo tee /etc/apt/sources.list.d/vedic.list
sudo apt update
sudo apt install vedic
vedic --version
```

2. **Verify repository**:
```bash
# Check package availability
apt-cache policy vedic

# Check repository signature
apt-key list
```

## Maintenance

### Adding a new release:
```bash
cd apt-repo
reprepro includedeb stable /path/to/vedic_x.x.x_amd64.deb
git add .
git commit -m "Add Vedic vX.X.X"
git push
```

### Removing old versions:
```bash
reprepro remove stable vedic
reprepro list stable
```

### Supporting multiple architectures:
Your `conf/distributions` already includes: amd64, arm64, armhf, i386

To add packages for different architectures:
```bash
reprepro includedeb stable vedic_2.0.6_amd64.deb
reprepro includedeb stable vedic_2.0.6_arm64.deb
reprepro includedeb stable vedic_2.0.6_armhf.deb
```

## Benefits of APT Repository

1. **Easy Updates**: Users can update with `apt upgrade`
2. **Dependency Management**: APT handles dependencies automatically
3. **Version Control**: Users can install specific versions
4. **Professional Distribution**: Standard package management
5. **Auto-completion**: Shell completions installed automatically

## Documentation Updates

Update your main README.md to include:

```markdown
### Install via APT (Debian/Ubuntu)

```bash
curl -fsSL https://vedic-lang.github.io/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/vedic.gpg
echo "deb [signed-by=/usr/share/keyrings/vedic.gpg] https://vedic-lang.github.io/apt stable main" | sudo tee /etc/apt/sources.list.d/vedic.list
sudo apt update
sudo apt install vedic
```
```

## Security Notes

- Keep `GPG_PRIVATE_KEY` secret secure
- Never commit private keys to repository
- Rotate GPG keys periodically
- Use strong passphrase for GPG key
- Limit APT_REPO_TOKEN to minimal permissions needed
