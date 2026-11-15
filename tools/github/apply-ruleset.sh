#!/usr/bin/env bash
# Applies Penny's repository settings and the branch ruleset for main.
# Idempotent: re-running updates the existing "main" ruleset in place.
#
# Usage: tools/github/apply-ruleset.sh [owner/repo]
# Needs: gh, authenticated with admin rights on the repository.
set -euo pipefail

REPO="${1:-tgwtea/penny}"

echo "Configuring merge settings on ${REPO}"
gh api --method PATCH "repos/${REPO}" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  >/dev/null

ruleset='{
  "name": "main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [ { "context": "ci-ok" }, { "context": "pr-title" } ]
      }
    }
  ]
}'

existing_id="$(gh api "repos/${REPO}/rulesets" --jq '.[] | select(.name == "main") | .id')"

if [ -n "${existing_id}" ]; then
  echo "Updating ruleset ${existing_id}"
  printf '%s' "${ruleset}" | gh api --method PUT "repos/${REPO}/rulesets/${existing_id}" --input - >/dev/null
else
  echo "Creating ruleset"
  printf '%s' "${ruleset}" | gh api --method POST "repos/${REPO}/rulesets" --input - >/dev/null
fi

echo "Done. main now requires a pull request, squash merges, linear history, and the ci-ok and pr-title checks."
