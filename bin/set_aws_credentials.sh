#!/bin/sh

AWS_SOURCE_PROFILE="${AWS_SOURCE_PROFILE:-cli-mfa-user}"

if ! command -v aws >/dev/null 2>&1; then
  echo "Error: aws CLI is not installed" >&2
  return 1 2>/dev/null || exit 1
fi

AWS_EXPORTS="$(aws configure export-credentials --profile "${AWS_SOURCE_PROFILE}" --format env)" || {
  echo "Error: failed to export credentials from profile ${AWS_SOURCE_PROFILE}" >&2
  return 1 2>/dev/null || exit 1
}

eval "${AWS_EXPORTS}"
unset AWS_PROFILE
unset AWS_DEFAULT_PROFILE

echo "AWS credentials exported from profile ${AWS_SOURCE_PROFILE}"
