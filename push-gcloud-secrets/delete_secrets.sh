#!/bin/bash

gcloud auth activate-service-account --key-file=credentials.json

delete_secret() {
  local secret_name=$1

  if gcloud secrets describe $secret_name --project=$PROJECT_ID &>/dev/null; then
    # If the secret exists, delete it
    gcloud secrets delete $secret_name --project=$PROJECT_ID --quiet
  else
    echo "Secret not found: $secret_name"
  fi
}

# Load variable names from .env file for deletion
while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]] && continue

  key=$(echo "$line" | cut -d'=' -f1)
  
  delete_secret "$key"
done < .env

echo "Secrets uploaded and deleted successfully."