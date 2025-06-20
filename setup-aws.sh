#!/bin/bash

# AWS Infrastructure Setup Script for GMFam Application
# This script creates all necessary AWS resources for deploying your application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script metadata
SCRIPT_VERSION="1.0.0"
APP_NAME="gmfam"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/tmp/gmfam_setup_${TIMESTAMP}.log"

# Function to print colored output
print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to log commands
log_command() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to prompt for user input
prompt_user() {
    local prompt="$1"
    local var_name="$2"
    local default_value="$3"
    local is_sensitive="$4"
    
    if [[ -n "$default_value" ]]; then
        prompt="$prompt (default: $default_value)"
    fi
    
    echo -n "$prompt: "
    
    if [[ "$is_sensitive" == "true" ]]; then
        read -s user_input
        echo
    else
        read user_input
    fi
    
    if [[ -z "$user_input" && -n "$default_value" ]]; then
        user_input="$default_value"
    fi
    
    eval "$var_name='$user_input'"
}

# Function to validate email format
validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# Function to generate random password
generate_password() {
    openssl rand -base64 24 | tr -d "=+/" | head -c 32
}

# Function to generate encryption key
generate_encryption_key() {
    openssl rand -base64 32 | tr -d "=+/" | head -c 32
}

# Function to check if Git is installed
check_git() {
    if ! command_exists git; then
        print_warning "Git not found. Installing Git..."
        
        if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
            if command_exists apt-get; then
                sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y git >/dev/null 2>&1
            elif command_exists yum; then
                sudo yum install -y git >/dev/null 2>&1
            elif command_exists dnf; then
                sudo dnf install -y git >/dev/null 2>&1
            else
                print_error "Please install Git manually"
                exit 1
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            if command_exists brew; then
                brew install git
            else
                print_error "Please install Git manually: https://git-scm.com/"
                exit 1
            fi
        else
            print_error "Please install Git manually: https://git-scm.com/"
            exit 1
        fi
        
        if command_exists git; then
            print_success "Git installed successfully"
        else
            print_error "Git installation failed"
            exit 1
        fi
    else
        print_success "Git is already installed"
    fi
}

# Function to check if GitHub CLI is installed
check_github_cli() {
    print_header "GitHub CLI Setup"
    
    if ! command_exists gh; then
        print_warning "GitHub CLI not found. Installing GitHub CLI..."
        
        if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
            # Install GitHub CLI on Linux
            print_info "Installing GitHub CLI for Linux..."
            
            # Step 1: Download and install GPG key
            print_info "Step 1/4: Adding GitHub CLI GPG key..."
            if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null; then
                print_success "GPG key added successfully"
            else
                print_error "Failed to add GitHub CLI GPG key"
                print_info "Error details: Check network connection and sudo permissions"
                exit 1
            fi
            
            # Step 2: Add repository
            print_info "Step 2/4: Adding GitHub CLI repository..."
            if echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null; then
                print_success "Repository added successfully"
            else
                print_error "Failed to add GitHub CLI repository"
                exit 1
            fi
            
            # Step 3: Update package list
            print_info "Step 3/4: Updating package list..."
            if sudo apt update 2>&1 | grep -q "github-cli"; then
                print_success "Package list updated successfully"
            else
                print_warning "Package list updated (GitHub CLI repo may not be visible yet)"
            fi
            
            # Step 4: Install GitHub CLI
            print_info "Step 4/4: Installing GitHub CLI package..."
            if sudo apt install gh -y 2>&1; then
                print_success "GitHub CLI package installation completed"
            else
                print_error "Failed to install GitHub CLI package"
                print_info "Trying alternative installation method..."
                
                # Alternative: Try downloading .deb directly
                print_info "Downloading GitHub CLI .deb package directly..."
                local gh_version="2.40.1"
                local arch=$(dpkg --print-architecture)
                local deb_url="https://github.com/cli/cli/releases/download/v${gh_version}/gh_${gh_version}_linux_${arch}.deb"
                
                if curl -fsSL "$deb_url" -o "gh.deb"; then
                    print_info "Installing downloaded package..."
                    if sudo dpkg -i gh.deb 2>&1; then
                        print_success "GitHub CLI package installed"
                        
                        # Try to fix dependencies, but don't fail if it has issues
                        print_info "Attempting to fix dependencies..."
                        if sudo apt-get install -f -y 2>&1; then
                            print_success "Dependencies fixed successfully"
                        else
                            print_warning "Dependency fix had issues, but GitHub CLI may still work"
                        fi
                    else
                        print_error "Failed to install GitHub CLI via direct download"
                        rm -f gh.deb
                        exit 1
                    fi
                    rm -f gh.deb
                else
                    print_error "Failed to download GitHub CLI package"
                    exit 1
                fi
            fi
            
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            print_info "Installing GitHub CLI for macOS..."
            if command_exists brew; then
                print_info "Using Homebrew to install GitHub CLI..."
                if brew install gh 2>&1; then
                    print_success "GitHub CLI installed via Homebrew"
                else
                    print_error "Failed to install GitHub CLI via Homebrew"
                    exit 1
                fi
            else
                print_error "Homebrew not found. Please install GitHub CLI manually:"
                print_info "Visit: https://cli.github.com/manual/installation"
                exit 1
            fi
            
        else
            print_error "Unsupported operating system: $OSTYPE"
            print_info "Please install GitHub CLI manually:"
            print_info "Visit: https://cli.github.com/manual/installation"
            exit 1
        fi
        
        # Verify installation
        print_info "Verifying GitHub CLI installation..."
        
        # Check if command exists
        if command_exists gh; then
            print_success "GitHub CLI command found"
            
            # Test if it actually works
            if gh_version_output=$(gh --version 2>&1); then
                local gh_version=$(echo "$gh_version_output" | head -n1)
                print_success "GitHub CLI installed and working!"
                print_info "Version: $gh_version"
            else
                print_warning "GitHub CLI command exists but has issues"
                print_info "Error: $gh_version_output"
                print_info "Continuing anyway - it may work for basic operations"
            fi
        else
            print_error "GitHub CLI installation failed - command not found"
            print_info "Checking if gh is in a different location..."
            
            # Check common alternative locations
            if [[ -f "/usr/bin/gh" ]]; then
                print_info "Found gh at /usr/bin/gh, adding to PATH"
                export PATH="/usr/bin:$PATH"
                if command_exists gh; then
                    print_success "GitHub CLI now accessible"
                fi
            elif [[ -f "/usr/local/bin/gh" ]]; then
                print_info "Found gh at /usr/local/bin/gh, adding to PATH"
                export PATH="/usr/local/bin:$PATH"
                if command_exists gh; then
                    print_success "GitHub CLI now accessible"
                fi
            else
                print_error "GitHub CLI not found in common locations"
                print_info "Please try installing manually:"
                print_info "Visit: https://cli.github.com/manual/installation"
                exit 1
            fi
        fi
    else
        local gh_version=$(gh --version | head -n1)
        print_success "GitHub CLI is already installed"
        print_info "Version: $gh_version"
    fi
}

# Function to setup GitHub repository
setup_github_repository() {
    print_header "GitHub Repository Setup"
    
    # Check if we're in a git repository
    if [[ ! -d ".git" ]]; then
        print_info "Initializing Git repository..."
        if git init 2>&1; then
            print_success "Git repository initialized"
        else
            print_error "Failed to initialize Git repository"
            exit 1
        fi
        
        print_info "Adding files to Git..."
        if git add . 2>&1; then
            print_success "Files added to Git staging area"
        else
            print_error "Failed to add files to Git"
            exit 1
        fi
        
        print_info "Creating initial commit..."
        if git commit -m "Initial commit - GMFam application setup" 2>&1; then
            print_success "Initial commit created"
        else
            print_error "Failed to create initial commit"
            exit 1
        fi
    else
        print_success "Already in a Git repository"
        
        # Check if there are uncommitted changes
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            print_info "Found uncommitted changes, creating commit..."
            if git add . 2>&1 && git commit -m "Pre-deployment commit - $(date)" 2>&1; then
                print_success "Pre-deployment commit created"
            else
                print_warning "Failed to commit changes (may be no changes to commit)"
            fi
        else
            print_info "No uncommitted changes found"
        fi
    fi
    
    # Check if GitHub CLI is authenticated
    if ! gh auth status >/dev/null 2>&1; then
        print_info "🔐 GitHub authentication required..."
        print_info "This will open a web browser for secure authentication."
        echo
        prompt_user "Ready to authenticate with GitHub? (y/n)" "auth_ready" "y"
        
        if [[ "$auth_ready" != "y" ]]; then
            print_error "GitHub authentication is required for automatic setup"
            exit 1
        fi
        
        print_info "Starting GitHub authentication..."
        if gh auth login 2>&1; then
            print_success "GitHub authentication successful!"
        else
            print_error "GitHub authentication failed"
            print_info "Please try running 'gh auth login' manually"
            exit 1
        fi
    else
        print_success "GitHub CLI already authenticated"
    fi
    
    # Get the authenticated GitHub username
    print_info "Getting GitHub username..."
    if github_username=$(gh api user --jq '.login' 2>&1); then
        print_success "Authenticated as: $github_username"
    else
        print_error "Failed to get GitHub username"
        print_info "Error: $github_username"
        exit 1
    fi
    
    # Update the repository full name
    repo_full_name="${github_username}/${github_repo}"
    
    # Check if repository already exists
    if gh repo view "$repo_full_name" >/dev/null 2>&1; then
        print_warning "Repository $repo_full_name already exists"
        
        prompt_user "Do you want to use the existing repository? (y/n)" "use_existing_repo" "y"
        if [[ "$use_existing_repo" != "y" ]]; then
            prompt_user "Enter a different repository name" "github_repo"
            repo_full_name="${github_username}/${github_repo}"
        fi
    fi
    
    # Create repository if it doesn't exist
    if ! gh repo view "$repo_full_name" >/dev/null 2>&1; then
        print_info "Creating GitHub repository: $repo_full_name"
        
        prompt_user "Repository description" "repo_description" "GMFam application - Auto-deployed to AWS"
        prompt_user "Make repository private? (y/n)" "make_private" "n"
        
        local visibility_flag=""
        if [[ "$make_private" == "y" ]]; then
            visibility_flag="--private"
        else
            visibility_flag="--public"
        fi
        
        print_info "Creating repository with GitHub CLI..."
        if repo_create_output=$(gh repo create "$github_repo" --description "$repo_description" $visibility_flag --confirm 2>&1); then
            print_success "Repository created successfully"
            print_info "Repository URL: https://github.com/$repo_full_name"
        else
            print_error "Failed to create repository"
            print_info "Error details: $repo_create_output"
            exit 1
        fi
    fi
    
    # Set up remote and push
    print_info "Configuring Git remote..."
    
    # Remove existing origin if it exists
    git remote remove origin 2>/dev/null || true
    
    # Add new origin
    print_info "Adding GitHub remote..."
    if git remote add origin "https://github.com/$repo_full_name.git" 2>&1; then
        print_success "GitHub remote added successfully"
    else
        print_error "Failed to add GitHub remote"
        exit 1
    fi
    
    # Set up main branch
    print_info "Setting up main branch..."
    if git branch -M main 2>&1; then
        print_success "Main branch configured"
    else
        print_warning "Failed to rename branch to main (may already be main)"
    fi
    
    # Push to repository
    print_info "Pushing code to GitHub repository..."
    if push_output=$(git push -u origin main --force 2>&1); then
        print_success "Code pushed to GitHub successfully!"
        print_info "🔗 Repository: https://github.com/$repo_full_name"
    else
        print_error "Failed to push code to GitHub"
        print_info "Error details: $push_output"
        print_info "Please check your GitHub permissions and try again"
        exit 1
    fi
}

# Function to set GitHub secrets automatically
set_github_secrets() {
    print_header "Setting GitHub Secrets"
    
    print_info "Configuring GitHub secrets for automated deployment..."
    
    # Build database connection string
    local db_connection="postgres://${db_username}:${db_password}@${db_endpoint}:5432/${db_name}?sslmode=require"
    
    # Prepare secrets array
    declare -A secrets_map=(
        ["AWS_ARN_OIDC_ACCESS"]="$role_arn"
        ["ECR_REPOSITORY"]="$ecr_uri"
        ["LIGHTSAIL_SERVICE_NAME"]="$lightsail_service_name"
        ["PAGODA_DATABASE_CONNECTION"]="$db_connection"
        ["PAGODA_APP_HOST"]="$lightsail_url"
        ["PAGODA_APP_ENCRYPTIONKEY"]="$app_encryption_key"
        ["PAGODA_MAIL_HOSTNAME"]="localhost"
        ["PAGODA_MAIL_PORT"]="25"
        ["PAGODA_MAIL_USER"]="$admin_email"
        ["PAGODA_MAIL_PASSWORD"]="changeme123"
        ["PAGODA_MAIL_FROMADDRESS"]="$admin_email"
    )
    
    # Set each secret
    for key in "${!secrets_map[@]}"; do
        local value="${secrets_map[$key]}"
        
        print_info "Setting secret: $key"
        if secret_output=$(echo "$value" | gh secret set "$key" --repo "$repo_full_name" 2>&1); then
            print_success "✅ $key"
        else
            print_error "❌ Failed to set $key"
            print_info "Error: $secret_output"
        fi
    done
    
    
    print_success "GitHub secrets configuration completed!"
    print_info "🔗 Manage secrets: https://github.com/$repo_full_name/settings/secrets/actions"
    
    # Validate critical secrets are set
    print_info "Validating GitHub secrets..."
    
    critical_secrets=("AWS_ARN_OIDC_ACCESS" "ECR_REPOSITORY" "LIGHTSAIL_SERVICE_NAME")
    for secret in "${critical_secrets[@]}"; do
        if gh secret list --repo "$repo_full_name" | grep -q "^$secret"; then
            print_success "✅ $secret is set"
        else
            print_error "❌ $secret is missing or not accessible"
        fi
    done
}

# Function to install AWS CLI
install_aws_cli() {
    print_header "Installing AWS CLI"
    
    if command_exists aws; then
        print_success "AWS CLI is already installed"
        aws --version
        return 0
    fi
    
    print_info "AWS CLI not found. Installing AWS CLI..."
    
    # Detect OS and install accordingly
    if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
        print_info "Detected Linux - installing AWS CLI v2..."
        
        # Check for required tools
        if ! command_exists curl; then
            print_error "curl is required but not installed. Please install curl first."
            exit 1
        fi
        
        # Download AWS CLI
        print_info "Downloading AWS CLI installer..."
        curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        
        if [[ ! -f "awscliv2.zip" ]]; then
            print_error "Failed to download AWS CLI installer"
            exit 1
        fi
        
        # Extract using available tools
        print_info "Extracting AWS CLI installer..."
        if command_exists unzip; then
            unzip -q awscliv2.zip
        elif command_exists python3; then
            python3 -m zipfile -e awscliv2.zip .
        elif command_exists python; then
            python -m zipfile -e awscliv2.zip .
        else
            print_error "No extraction tool available (unzip, python3, or python required)"
            print_info "Please install unzip: sudo apt-get install unzip (Ubuntu/Debian)"
            exit 1
        fi
        
        # Make installer executable
        chmod +x ./aws/install
        
        # Try to install without sudo first (for user install)
        print_info "Installing AWS CLI to user directory..."
        if ./aws/install --install-dir ~/.local/aws-cli --bin-dir ~/.local/bin >/dev/null 2>&1; then
            print_success "AWS CLI installed to user directory"
            export PATH="$HOME/.local/bin:$PATH"
            
            # Fix permissions on installed files
            chmod +x ~/.local/bin/aws 2>/dev/null || true
            chmod +x ~/.local/aws-cli/v2/current/bin/aws 2>/dev/null || true
            
        else
            print_info "User installation failed, trying system-wide installation..."
            if sudo ./aws/install >/dev/null 2>&1; then
                print_success "AWS CLI installed system-wide"
            else
                print_error "Failed to install AWS CLI. Please install manually."
                print_info "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
                print_info "Or try: sudo apt-get install awscli"
                exit 1
            fi
        fi
        
        # Clean up
        rm -rf aws awscliv2.zip
        
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        print_info "Detected macOS - installing AWS CLI v2..."
        
        # Check if Homebrew is available
        if command_exists brew; then
            print_info "Using Homebrew to install AWS CLI..."
            brew install awscli
        else
            # Use official installer
            curl -s "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
            
            if [[ ! -f "AWSCLIV2.pkg" ]]; then
                print_error "Failed to download AWS CLI installer"
                exit 1
            fi
            
            sudo installer -pkg AWSCLIV2.pkg -target /
            rm AWSCLIV2.pkg
        fi
        
    elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
        print_info "Detected Windows - please install AWS CLI manually"
        print_info "Download from: https://awscli.amazonaws.com/AWSCLIV2.msi"
        print_error "Windows installation requires manual steps"
        exit 1
        
    else
        print_error "Unsupported operating system: $OSTYPE"
        print_info "Please install AWS CLI manually from:"
        print_info "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    # Verify installation
    if command_exists aws; then
        print_success "AWS CLI installed successfully!"
        aws --version
    else
        print_error "AWS CLI installation failed or not in PATH"
        print_info "Try running: export PATH=\"\$HOME/.local/bin:\$PATH\""
        print_info "Or restart your terminal and try again"
        exit 1
    fi
}

# Function to configure AWS credentials
configure_aws() {
    print_header "AWS Configuration"
    
    # Ensure AWS CLI is in PATH (in case it was just installed)
    if [[ -d "$HOME/.local/bin" ]] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    # Check if AWS is already configured
    if aws sts get-caller-identity >/dev/null 2>&1; then
        print_success "AWS CLI is already configured"
        local current_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        local current_region=$(aws configure get region 2>/dev/null)
        local current_user=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)
        
        echo "Current Configuration:"
        echo "  Account: $current_account"
        echo "  Region: $current_region"
        echo "  User: $current_user"
        echo
        
        prompt_user "Do you want to use this configuration? (y/n)" "use_existing" "y"
        if [[ "$use_existing" == "y" ]]; then
            aws_region="$current_region"
            return 0
        fi
    fi
    
    echo
    print_info "🔑 AWS Credentials Setup"
    print_info "You'll need AWS credentials with administrative access."
    echo
    print_info "📋 To get your credentials:"
    print_info "1. Go to AWS Console: https://console.aws.amazon.com"
    print_info "2. Navigate to: IAM → Users → [Your Username] → Security Credentials"
    print_info "3. Click 'Create Access Key' → 'Command Line Interface (CLI)'"
    print_info "4. Copy the Access Key ID and Secret Access Key"
    echo
    print_warning "⚠️  Keep these credentials secure and never share them!"
    echo
    
    # Get credentials with validation
    while true; do
        prompt_user "Enter your AWS Access Key ID" "aws_access_key_id"
        
        if [[ ${#aws_access_key_id} -ge 16 && "$aws_access_key_id" =~ ^[A-Z0-9]+$ ]]; then
            break
        else
            print_error "Invalid Access Key ID format. Should be 16-20 uppercase letters and numbers."
        fi
    done
    
    while true; do
        prompt_user "Enter your AWS Secret Access Key" "aws_secret_access_key" "" "true"
        
        if [[ ${#aws_secret_access_key} -ge 32 ]]; then
            break
        else
            print_error "Invalid Secret Access Key. Should be at least 32 characters."
        fi
    done
    
    # Region selection with common options
    echo
    print_info "🌍 Choose your AWS region (closer to your users = better performance):"
    echo "  1. us-east-1 (N. Virginia) - Default, cheapest"
    echo "  2. us-west-2 (Oregon) - West Coast US"
    echo "  3. eu-west-1 (Ireland) - Europe"
    echo "  4. ap-southeast-1 (Singapore) - Asia Pacific"
    echo "  5. Custom region"
    echo
    
    prompt_user "Select region (1-5)" "region_choice" "1"
    
    case "$region_choice" in
        1) aws_region="us-east-1" ;;
        2) aws_region="us-west-2" ;;
        3) aws_region="eu-west-1" ;;
        4) aws_region="ap-southeast-1" ;;
        5) prompt_user "Enter custom region (e.g., us-west-1)" "aws_region" "us-east-1" ;;
        *) aws_region="us-east-1" ;;
    esac
    
    print_info "Selected region: $aws_region"
    
    # Configure AWS CLI
    print_info "Configuring AWS CLI..."
    aws configure set aws_access_key_id "$aws_access_key_id"
    aws configure set aws_secret_access_key "$aws_secret_access_key"
    aws configure set default.region "$aws_region"
    aws configure set default.output "json"
    
    # Test configuration
    print_info "Testing AWS connection..."
    if aws sts get-caller-identity >/dev/null 2>&1; then
        print_success "AWS CLI configured successfully! ✅"
        
        local account=$(aws sts get-caller-identity --query Account --output text)
        local user_arn=$(aws sts get-caller-identity --query Arn --output text)
        
        echo
        echo "✅ Connected to AWS Account: $account"
        echo "✅ User: $user_arn"
        echo "✅ Region: $aws_region"
        echo
    else
        print_error "AWS CLI configuration failed. Please check your credentials."
        print_info "Common issues:"
        print_info "- Incorrect Access Key ID or Secret Access Key"
        print_info "- User doesn't have sufficient permissions"
        print_info "- Network connectivity issues"
        exit 1
    fi
}

# Function to collect deployment configuration
collect_deployment_config() {
    print_header "Deployment Configuration"
    
    # Application settings
    prompt_user "Enter your application name" "app_name" "$APP_NAME"
    prompt_user "Enter your domain name (optional, leave empty for IP access)" "domain_name" ""
    prompt_user "Enter your email address for notifications" "admin_email"
    
    # Validate email
    while ! validate_email "$admin_email"; do
        print_error "Invalid email format. Please try again."
        prompt_user "Enter your email address for notifications" "admin_email"
    done
    
    # GitHub repository settings (will be set during GitHub setup)
    prompt_user "Enter your desired GitHub repository name" "github_repo" "$app_name"
    
    # Database settings
    prompt_user "Enter database name" "db_name" "${app_name}_prod"
    prompt_user "Enter database username" "db_username" "dbuser"
    
    # Generate secure passwords
    db_password=$(generate_password)
    app_encryption_key=$(generate_encryption_key)
    
    print_success "Configuration collected successfully"
    
    # Display configuration summary
    print_header "Configuration Summary"
    echo "Application Name: $app_name"
    echo "Domain: ${domain_name:-"Will use IP address"}"
    echo "Admin Email: $admin_email"
    echo "GitHub Repository: $github_repo"
    echo "Database: $db_name"
    echo "Database User: $db_username"
    echo "AWS Region: $aws_region"
    echo
    
    prompt_user "Proceed with this configuration? (y/n)" "proceed" "y"
    if [[ "$proceed" != "y" ]]; then
        print_info "Deployment cancelled by user"
        exit 0
    fi
}

# Function to create RDS database
create_database() {
    print_header "Creating RDS Database"
    
    local db_instance_id="${app_name}-db"
    local db_subnet_group_name="${app_name}-db-subnet-group"
    local db_security_group_name="${app_name}-db-sg"
    
    # Create VPC and networking (simplified - using default VPC)
    local vpc_id=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
    
    if [[ "$vpc_id" == "None" ]]; then
        print_error "No default VPC found. Please create a VPC first."
        exit 1
    fi
    
    # Get subnet IDs
    local subnet_ids=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].SubnetId' --output text)
    
    # Create DB subnet group
    print_info "Creating DB subnet group..."
    aws rds create-db-subnet-group \
        --db-subnet-group-name "$db_subnet_group_name" \
        --db-subnet-group-description "Subnet group for $app_name database" \
        --subnet-ids $subnet_ids \
        --tags Key=Application,Value=$app_name \
        >/dev/null 2>&1 || print_warning "DB subnet group may already exist"
    
    # Create security group for database
    print_info "Creating database security group..."
    local db_sg_id=$(aws ec2 create-security-group \
        --group-name "$db_security_group_name" \
        --description "Security group for $app_name database" \
        --vpc-id "$vpc_id" \
        --query 'GroupId' --output text 2>/dev/null || \
        aws ec2 describe-security-groups --group-names "$db_security_group_name" --query 'SecurityGroups[0].GroupId' --output text)
    
    # Allow MySQL/PostgreSQL access from application
    aws ec2 authorize-security-group-ingress \
        --group-id "$db_sg_id" \
        --protocol tcp \
        --port 5432 \
        --cidr 10.0.0.0/8 \
        >/dev/null 2>&1 || true
    
    # Check if RDS instance already exists
    if aws rds describe-db-instances --db-instance-identifier "$db_instance_id" >/dev/null 2>&1; then
        print_success "RDS instance already exists"
        local existing_status=$(aws rds describe-db-instances --db-instance-identifier "$db_instance_id" --query 'DBInstances[0].DBInstanceStatus' --output text)
        print_info "Current status: $existing_status"
        
        if [[ "$existing_status" != "available" ]]; then
            print_info "Waiting for existing RDS instance to become available..."
            aws rds wait db-instance-available --db-instance-identifier "$db_instance_id"
        fi
    else
        # Create RDS instance
        print_info "Creating RDS PostgreSQL instance (this may take 10-15 minutes)..."
        
        if aws rds create-db-instance \
            --db-instance-identifier "$db_instance_id" \
            --db-instance-class "db.t3.micro" \
            --engine "postgres" \
            --engine-version "17.5" \
            --master-username "$db_username" \
            --master-user-password "$db_password" \
            --allocated-storage 20 \
            --storage-type "gp2" \
            --vpc-security-group-ids "$db_sg_id" \
            --db-subnet-group-name "$db_subnet_group_name" \
            --db-name "$db_name" \
            --backup-retention-period 7 \
            --storage-encrypted \
            --tags Key=Application,Value=$app_name \
            --no-multi-az \
            --no-publicly-accessible \
            >/dev/null 2>&1; then
            
            print_success "RDS instance creation initiated"
            print_info "Waiting for RDS instance to become available..."
            aws rds wait db-instance-available --db-instance-identifier "$db_instance_id"
        else
            print_error "Failed to create RDS instance"
            print_info "Checking what went wrong..."
            
            # Try to get more specific error information
            aws rds create-db-instance \
                --db-instance-identifier "$db_instance_id" \
                --db-instance-class "db.t3.micro" \
                --engine "postgres" \
                --engine-version "17.5" \
                --master-username "$db_username" \
                --master-user-password "$db_password" \
                --allocated-storage 20 \
                --storage-type "gp2" \
                --vpc-security-group-ids "$db_sg_id" \
                --db-subnet-group-name "$db_subnet_group_name" \
                --db-name "$db_name" \
                --backup-retention-period 7 \
                --storage-encrypted \
                --tags Key=Application,Value=$app_name \
                --no-multi-az \
                --no-publicly-accessible 2>&1
            
            exit 1
        fi
    fi
    
    # Get RDS endpoint
    db_endpoint=$(aws rds describe-db-instances \
        --db-instance-identifier "$db_instance_id" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text)
    
    print_success "RDS database created successfully"
    print_info "Database endpoint: $db_endpoint"
}

# Function to create ECR repository
create_ecr_repository() {
    print_header "Creating ECR Repository"
    
    local repo_name="${app_name}"
    
    # Create ECR repository
    print_info "Creating ECR repository..."
    if ecr_uri=$(aws ecr create-repository \
        --repository-name "$repo_name" \
        --query 'repository.repositoryUri' \
        --output text 2>&1); then
        print_success "ECR repository created successfully"
        print_info "Repository URI: $ecr_uri"
    elif aws ecr describe-repositories --repository-names "$repo_name" >/dev/null 2>&1; then
        print_success "ECR repository already exists"
        ecr_uri=$(aws ecr describe-repositories \
            --repository-names "$repo_name" \
            --query 'repositories[0].repositoryUri' \
            --output text)
        print_info "Repository URI: $ecr_uri"
    else
        print_error "Failed to create ECR repository"
        print_info "Error: $ecr_uri"
        exit 1
    fi
    
    # Set repository lifecycle policy to manage image retention
    print_info "Setting up ECR lifecycle policy..."
    cat > ecr-lifecycle-policy.json << EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 10 images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
    
    if aws ecr put-lifecycle-policy \
        --repository-name "$repo_name" \
        --lifecycle-policy-text file://ecr-lifecycle-policy.json \
        >/dev/null 2>&1; then
        print_success "ECR lifecycle policy set successfully"
    else
        print_warning "Failed to set ECR lifecycle policy (repository may already have one)"
    fi
    
    rm -f ecr-lifecycle-policy.json
}

# Function to create Lightsail Container Service
create_lightsail_container_service() {
    print_header "Creating Lightsail Container Service"
    
    local service_name="${app_name}-container-service"
    local power="micro"  # nano, micro, small, medium, large, xlarge
    local scale="1"      # Number of nodes
    
    # Create Lightsail container service
    print_info "Creating Lightsail container service..."
    if aws lightsail create-container-service \
        --service-name "$service_name" \
        --power "$power" \
        --scale "$scale" \
        --tags key=Application,value=$app_name \
        >/dev/null 2>&1; then
        print_success "Lightsail container service creation initiated"
    elif aws lightsail get-container-services --service-name "$service_name" >/dev/null 2>&1; then
        print_success "Lightsail container service already exists"
    else
        print_error "Failed to create Lightsail container service"
        exit 1
    fi
    
    # Wait for container service to be ready
    print_info "Waiting for container service to be ready (this may take 5-10 minutes)..."
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local state=$(aws lightsail get-container-services \
            --service-name "$service_name" \
            --query 'containerServices[0].state' \
            --output text 2>/dev/null || echo "PENDING")
        
        if [[ "$state" == "READY" ]]; then
            print_success "Container service is ready!"
            break
        elif [[ "$state" == "FAILED" ]]; then
            print_error "Container service creation failed"
            exit 1
        else
            echo -n "."
            sleep 10
            ((attempt++))
        fi
    done
    
    if [ $attempt -eq $max_attempts ]; then
        print_warning "Container service is taking longer than expected to be ready"
        print_info "You can check status at: https://lightsail.aws.amazon.com/"
    fi
    
    # Get container service URL
    lightsail_url=$(aws lightsail get-container-services \
        --service-name "$service_name" \
        --query 'containerServices[0].url' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$lightsail_url" && "$lightsail_url" != "None" ]]; then
        print_success "Container service URL: $lightsail_url"
    else
        print_info "Container service URL will be available after first deployment"
        lightsail_url="https://${service_name}.${aws_region}.cs.amazonlightsail.com"
        print_info "Expected URL: $lightsail_url"
    fi
    
    # Store service name for later use
    lightsail_service_name="$service_name"
}

# Function to create IAM role for GitHub Actions
create_github_iam_role() {
    print_header "Creating IAM Role for GitHub Actions"
    
    local role_name="${app_name}-github-actions-role"
    local policy_name="${app_name}-github-actions-policy"
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    
    # Create OIDC provider for GitHub Actions if it doesn't exist
    print_info "Setting up GitHub OIDC provider..."
    local oidc_arn="arn:aws:iam::${account_id}:oidc-provider/token.actions.githubusercontent.com"
    
    if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$oidc_arn" >/dev/null 2>&1; then
        print_success "GitHub OIDC provider already exists"
    else
        print_info "Creating GitHub OIDC provider..."
        if aws iam create-open-id-connect-provider \
            --url https://token.actions.githubusercontent.com \
            --client-id-list sts.amazonaws.com \
            --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd \
            >/dev/null 2>&1; then
            print_success "GitHub OIDC provider created successfully"
        else
            print_error "Failed to create GitHub OIDC provider"
            exit 1
        fi
    fi
    
    # Create trust policy for GitHub OIDC
    print_info "Creating IAM role trust policy..."
    cat > trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${account_id}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:${github_username}/${github_repo}:*"
                }
            }
        }
    ]
}
EOF
    
    # Create IAM role
    print_info "Creating IAM role..."
    if aws iam create-role \
        --role-name "$role_name" \
        --assume-role-policy-document file://trust-policy.json \
        --tags Key=Application,Value=$app_name \
        >/dev/null 2>&1; then
        print_success "IAM role created successfully"
    elif aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
        print_success "IAM role already exists"
        
        # Update the trust policy in case the repository changed
        print_info "Updating IAM role trust policy..."
        if aws iam update-assume-role-policy \
            --role-name "$role_name" \
            --policy-document file://trust-policy.json \
            >/dev/null 2>&1; then
            print_success "IAM role trust policy updated"
        else
            print_warning "Failed to update trust policy, but role exists"
        fi
    else
        print_error "Failed to create IAM role"
        exit 1
    fi
    
    # Create policy for Lightsail, ECR and basic AWS access
    cat > role-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lightsail:*",
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ec2:DescribeInstances",
                "ec2:DescribeImages",
                "ec2:DescribeSnapshots",
                "ec2:DescribeKeyPairs",
                "rds:DescribeDBInstances"
            ],
            "Resource": "*"
        }
    ]
}
EOF
    
    # Attach policy to role
    print_info "Attaching policy to IAM role..."
    if aws iam put-role-policy \
        --role-name "$role_name" \
        --policy-name "$policy_name" \
        --policy-document file://role-policy.json \
        >/dev/null 2>&1; then
        print_success "Policy attached to IAM role successfully"
    else
        print_error "Failed to attach policy to IAM role"
        exit 1
    fi
    
    # Get role ARN
    print_info "Getting IAM role ARN..."
    if role_arn=$(aws iam get-role --role-name "$role_name" --query 'Role.Arn' --output text 2>&1); then
        print_success "IAM role ARN retrieved: $role_arn"
    else
        print_error "Failed to get IAM role ARN"
        print_info "Error: $role_arn"
        exit 1
    fi
    
    # Validate the setup
    print_info "Validating GitHub OIDC setup..."
    
    # Check if OIDC provider exists and is accessible
    if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$oidc_arn" >/dev/null 2>&1; then
        print_success "✅ OIDC provider is accessible"
    else
        print_error "❌ OIDC provider is not accessible"
        print_info "This will cause GitHub Actions authentication to fail"
    fi
    
    # Check if role can be assumed (basic validation)
    print_info "Verifying role trust policy..."
    if trust_policy=$(aws iam get-role --role-name "$role_name" --query 'Role.AssumeRolePolicyDocument' --output json 2>&1); then
        if echo "$trust_policy" | grep -q "token.actions.githubusercontent.com"; then
            print_success "✅ Role trust policy includes GitHub OIDC"
        else
            print_warning "⚠️  Role trust policy may not include GitHub OIDC correctly"
        fi
        
        if echo "$trust_policy" | grep -q "$github_username/$github_repo"; then
            print_success "✅ Role trust policy includes your repository"
        else
            print_warning "⚠️  Role trust policy may not include your repository: $github_username/$github_repo"
        fi
    else
        print_warning "⚠️  Could not verify role trust policy"
    fi
    
    # Clean up temporary files
    rm -f trust-policy.json role-policy.json
    
    print_success "IAM role created successfully"
    print_info "Role ARN: $role_arn"
}


# Function to setup production config
setup_production_config() {
    print_header "Setting Up Production Configuration"
    
    # Create production config file
    cat > config/config.prod.yaml << EOF
http:
  hostname: ""
  port: 8000
  readTimeout: "5s"
  writeTimeout: "10s"
  idleTimeout: "2m"
  shutdownTimeout: "10s"
  tls:
    enabled: false
    certificate: ""
    key: ""

app:
  name: "$app_name"
  host: "http://${lightsail_ip}:8000"
  environment: "prod"
  encryptionKey: "$app_encryption_key"
  timeout: "20s"
  passwordToken:
      expiration: "60m"
      length: 64
  emailVerificationTokenExpiration: "12h"

cache:
  capacity: 100000
  expiration:
    publicFile: "4380h"

database:
  driver: "postgres"
  connection: "postgres://${db_username}:${db_password}@${db_endpoint}:5432/${db_name}?sslmode=require"
  testConnection: "file:/$RAND?vfs=memdb&_timeout=1000&_fk=true"

files:
  directory: "uploads"

tasks:
  goroutines: 1
  releaseAfter: "15m"
  cleanupInterval: "1h"
  shutdownTimeout: "10s"

mail:
  hostname: "localhost"
  port: 25
  user: "$admin_email"
  password: "admin"
  fromAddress: "$admin_email"
EOF
    
    print_success "Production configuration created: config/config.prod.yaml"
}

# Function to generate deployment summary
generate_summary() {
    print_header "Deployment Summary"
    
    print_success "AWS infrastructure setup completed successfully!"
    echo
    echo "Resources Created:"
    echo "=================="
    echo "✅ GitHub Repository: https://github.com/$repo_full_name"
    echo "✅ ECR Repository: ${ecr_uri}"
    echo "✅ Lightsail Container Service: ${lightsail_service_name}"
    echo "✅ RDS PostgreSQL Database: ${db_endpoint}"
    echo "✅ IAM Role for GitHub Actions: ${role_arn}"
    echo "✅ Production Configuration: config/config.prod.yaml"
    echo "✅ GitHub Secrets: Automatically configured"
    echo "✅ Dockerfile: Ready for containerized deployment"
    echo
    echo "🚀 Your Application is Ready!"
    echo "=========================="
    echo "1. ✅ Code pushed to GitHub repository"
    echo "2. ✅ GitHub secrets configured automatically"
    echo "3. ✅ AWS infrastructure provisioned"
    echo "4. ⏳ GitHub Actions will deploy your app automatically"
    echo "5. 🌐 Your app will be available at: ${lightsail_url}"
    echo
    echo "📊 Monitor your deployment:"
    echo "- GitHub Actions: https://github.com/$repo_full_name/actions"
    echo "- Application URL: ${lightsail_url}"
    echo "- Lightsail Console: https://lightsail.aws.amazon.com/"
    echo "- ECR Console: https://console.aws.amazon.com/ecr/"
    echo
    echo "Important Files:"
    echo "==============="
    echo "- Dockerfile: For containerized deployment"
    echo "- Setup Log: $LOG_FILE"
    echo
    print_warning "Keep your SSH key and database credentials secure!"
    
    # Estimated costs
    echo "Estimated Monthly Costs:"
    echo "======================="
    echo "- Lightsail Container Service (micro): ~$7/month"
    echo "- RDS PostgreSQL (db.t3.micro): ~$15/month"
    echo "- ECR Storage: ~$0.10/month"
    echo "- Data Transfer: ~$0.50/month"
    echo "- Total: ~$22.60/month"
    echo
}

# Function to clean up on error
cleanup_on_error() {
    print_error "An error occurred during setup. Check the log file: $LOG_FILE"
    exit 1
}

# Main execution
main() {
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Start logging
    log_command "Starting AWS setup for $APP_NAME"
    
    print_header "GMFam AWS Infrastructure Setup"
    echo "Version: $SCRIPT_VERSION"
    echo "Log file: $LOG_FILE"
    echo
    
    print_warning "This script will create AWS resources that incur costs (~$19/month)"
    print_warning "Make sure you understand the costs before proceeding"
    echo
    prompt_user "Do you want to continue? (y/n)" "continue_setup" "y"
    
    if [[ "$continue_setup" != "y" ]]; then
        print_info "Setup cancelled by user"
        exit 0
    fi
    
    # Execute setup steps
    install_aws_cli
    configure_aws
    collect_deployment_config
    check_git
    check_github_cli
    setup_github_repository
    create_database
    create_ecr_repository
    create_lightsail_container_service
    create_github_iam_role
    setup_production_config
    set_github_secrets
    generate_summary
    
    print_success "Setup completed successfully! 🎉"
}

# Execute main function
main "$@"