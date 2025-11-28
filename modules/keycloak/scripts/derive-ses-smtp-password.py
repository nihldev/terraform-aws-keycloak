#!/usr/bin/env python3
"""
Derive SES SMTP password from IAM secret access key.

This script implements the AWS SES SMTP password derivation algorithm
as documented at:
https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html

Usage (Terraform external data source):
    echo '{"secret_key": "...", "region": "us-east-1"}' | python3 derive-ses-smtp-password.py

Output:
    {"smtp_password": "..."}
"""

import base64
import hashlib
import hmac
import json
import sys

# AWS SES SMTP password derivation constants
DATE = "11111111"
SERVICE = "ses"
TERMINAL = "aws4_request"
MESSAGE = "SendRawEmail"
VERSION = bytes([0x04])


def sign(key: bytes, msg: str) -> bytes:
    """Create HMAC-SHA256 signature."""
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()


def derive_smtp_password(secret_key: str, region: str) -> str:
    """
    Derive SES SMTP password from IAM secret access key.

    Args:
        secret_key: IAM secret access key
        region: AWS region (e.g., 'us-east-1')

    Returns:
        Base64-encoded SMTP password
    """
    # Step 1: Create initial signature key
    signature = sign(("AWS4" + secret_key).encode("utf-8"), DATE)

    # Step 2: Sign region
    signature = sign(signature, region)

    # Step 3: Sign service
    signature = sign(signature, SERVICE)

    # Step 4: Sign terminal
    signature = sign(signature, TERMINAL)

    # Step 5: Sign message
    signature = sign(signature, MESSAGE)

    # Step 6: Prepend version byte and base64 encode
    smtp_password = base64.b64encode(VERSION + signature).decode("utf-8")

    return smtp_password


def main():
    """Read input from stdin, derive password, output JSON."""
    try:
        # Read JSON input from stdin (Terraform external data source format)
        input_data = json.load(sys.stdin)

        secret_key = input_data.get("secret_key")
        region = input_data.get("region")

        if not secret_key:
            print(json.dumps({"error": "secret_key is required"}), file=sys.stderr)
            sys.exit(1)

        if not region:
            print(json.dumps({"error": "region is required"}), file=sys.stderr)
            sys.exit(1)

        # Derive the SMTP password
        smtp_password = derive_smtp_password(secret_key, region)

        # Output in Terraform external data source format
        print(json.dumps({"smtp_password": smtp_password}))

    except json.JSONDecodeError as e:
        print(json.dumps({"error": f"Invalid JSON input: {e}"}), file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
