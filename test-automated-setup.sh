#!/bin/bash

# Automated test version of the setup script with preset answers
# This allows us to test the full flow without manual input

export TEST_MODE="true"
export AWS_REGION="us-east-1"
export APP_NAME="gmfam-test"
export DOMAIN_NAME=""
export ADMIN_EMAIL="test@example.com"
export GITHUB_USERNAME="testuser"
export GITHUB_REPO="gmfam-test"
export DB_NAME="gmfam_test_db"
export DB_USERNAME="testadmin"

# Source the original script but override prompts
source ./setup-aws.sh