#!/bin/bash

# Setup GCS Backend for Terraform State
# This script creates a GCS bucket to store Terraform state
# The same bucket will be used across local machine and Cloud Shell

PROJECT_ID="my-project-1101-476915"
BUCKET_NAME="${PROJECT_ID}-terraform-state"
LOCATION="asia-northeast1"

echo "=========================================="
echo "Setting up Terraform Remote State Backend"
echo "=========================================="
echo ""
echo "Project ID: $PROJECT_ID"
echo "Bucket Name: $BUCKET_NAME"
echo "Location: $LOCATION"
echo ""

# Check if bucket already exists
if gsutil ls -b gs://$BUCKET_NAME &>/dev/null; then
  echo "✓ Bucket gs://$BUCKET_NAME already exists"
else
  echo "Creating GCS bucket..."
  gsutil mb -p $PROJECT_ID -l $LOCATION -b on gs://$BUCKET_NAME
  
  # Enable versioning for state file safety
  echo "Enabling versioning..."
  gsutil versioning set on gs://$BUCKET_NAME
  
  echo "✓ Bucket created successfully"
fi

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Initialize Terraform with remote backend:"
echo "   terraform init -reconfigure"
echo ""
echo "2. Your state will be stored at:"
echo "   gs://$BUCKET_NAME/region-failover/default.tfstate"
echo ""
echo "3. Now you can run terraform from:"
echo "   • Local machine"
echo "   • Cloud Shell"
echo "   • CI/CD pipeline"
echo ""
echo "   All will share the same state! 🎉"
echo ""
