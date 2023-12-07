#!/bin/bash

gcloud auth activate-service-account --key-file=credentials.json

create_update_secret() {
  local secret_name=$1
  local secret_value=$2

  if gcloud secrets describe $secret_name --project=$PROJECT_ID &>/dev/null; then
    # If the secret exists, update it
    gcloud secrets versions add $secret_name --data-file <(echo -n "$secret_value") --project=$PROJECT_ID
  else
    gcloud secrets create $secret_name --data-file <(echo -n "$secret_value") --project=$PROJECT_ID
  fi
}

# Load variables from .env file
while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]] && continue

  key=$(echo "$line" | cut -d'=' -f1)
  value=$(echo "$line" | cut -d'=' -f2-)
  value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

  # Check if the line continues with \
  while [[ "$line" =~ \\$ ]]; do
    read -r next_line
    value+="\\n$next_line"
    line=$next_line
  done

  # Create or update the secret
  create_update_secret "$key" "$value"
done < .env

echo "Secrets uploaded successfully."