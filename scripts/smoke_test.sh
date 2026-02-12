#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-${BASE_URL:-}}"
if [[ -z "$BASE_URL" ]]; then
  echo "Usage: $0 <base_url>" >&2
  echo "Example: $0 https://snappass.tutima.com" >&2
  exit 1
fi

BASE_URL="${BASE_URL%/}"
BASE_HOST="$(printf '%s' "$BASE_URL" | sed -E 's#https?://([^/]+).*#\1#')"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

assert_status() {
  local label="$1"
  local got="$2"
  local want="$3"
  if [[ "$got" != "$want" ]]; then
    fail "$label expected HTTP $want, got $got"
  fi
}

extract_first_link() {
  local file="$1"
  grep -Eo 'https?://[^"<> ]+' "$file" | grep -E "$BASE_HOST" | grep -E '/\\?t=|/snappass' | head -n 1 || true
}

echo "[1/6] Home page"
home_status="$(curl -ksS -o "$TMP_DIR/home.html" -w "%{http_code}" "$BASE_URL/")"
assert_status "GET /" "$home_status" "200"

echo "[2/6] Query-token flow"
secret_query="SmokeQuery-$(date +%s)-$RANDOM"
curl -ksS -X POST "$BASE_URL/" --data-urlencode "password=$secret_query" --data "ttl=Hour" >"$TMP_DIR/confirm_query.html"
query_link="$(extract_first_link "$TMP_DIR/confirm_query.html")"
[[ -n "$query_link" ]] || fail "Could not parse query link from confirmation page"

query_preview_status="$(curl -ksS -o "$TMP_DIR/query_preview.html" -w "%{http_code}" "$query_link")"
assert_status "GET query link" "$query_preview_status" "200"

query_reveal_status="$(curl -ksS -X POST -d '' -o "$TMP_DIR/query_reveal.html" -w "%{http_code}" "$query_link")"
assert_status "POST query link" "$query_reveal_status" "200"
grep -Fq "$secret_query" "$TMP_DIR/query_reveal.html" || fail "Revealed query page does not contain expected secret"

query_second_status="$(curl -ksS -X POST -d '' -o "$TMP_DIR/query_second.html" -w "%{http_code}" "$query_link")"
assert_status "POST query link second time" "$query_second_status" "404"

echo "[3/6] Path-token flow"
secret_path="SmokePath-$(date +%s)-$RANDOM"
curl -ksS -X POST "$BASE_URL/" --data-urlencode "password=$secret_path" --data "ttl=Hour" >"$TMP_DIR/confirm_path.html"
query_link_for_path="$(extract_first_link "$TMP_DIR/confirm_path.html")"
[[ -n "$query_link_for_path" ]] || fail "Could not parse link for path-token test"

path_token="${query_link_for_path#*?t=}"
path_link="$BASE_URL/$path_token"

path_preview_status="$(curl -ksS -o "$TMP_DIR/path_preview.html" -w "%{http_code}" "$path_link")"
assert_status "GET path link" "$path_preview_status" "200"

path_reveal_status="$(curl -ksS -X POST -d '' -o "$TMP_DIR/path_reveal.html" -w "%{http_code}" "$path_link")"
assert_status "POST path link" "$path_reveal_status" "200"
grep -Fq "$secret_path" "$TMP_DIR/path_reveal.html" || fail "Revealed path page does not contain expected secret"

path_second_status="$(curl -ksS -X POST -d '' -o "$TMP_DIR/path_second.html" -w "%{http_code}" "$path_link")"
assert_status "POST path link second time" "$path_second_status" "404"

echo "[4/6] Legacy API (/api/set_password/)"
api_legacy_status="$(curl -ksS -H 'Content-Type: application/json' -d '{"password":"LegacyApiSecret","ttl":3600}' -o "$TMP_DIR/api_legacy.json" -w "%{http_code}" "$BASE_URL/api/set_password/")"
assert_status "POST /api/set_password/" "$api_legacy_status" "200"
grep -q '"link"' "$TMP_DIR/api_legacy.json" || fail "Legacy API response missing link"

echo "[5/6] Modern API (/api/v2/passwords)"
api_secret="SmokeApi-$(date +%s)-$RANDOM"
api_v2_status="$(curl -ksS -H 'Content-Type: application/json' -d "{\"password\":\"$api_secret\",\"ttl\":3600}" -o "$TMP_DIR/api_v2.json" -w "%{http_code}" "$BASE_URL/api/v2/passwords")"
assert_status "POST /api/v2/passwords" "$api_v2_status" "200"

api_self="$(grep -Eo 'https?://[^" ]+/api/v2/passwords/[^" ]+' "$TMP_DIR/api_v2.json" | head -n 1 || true)"
[[ -n "$api_self" ]] || fail "Could not parse self link from /api/v2/passwords response"

api_head_before="$(curl -ksS -I -o "$TMP_DIR/api_head_before.txt" -w "%{http_code}" "$api_self")"
assert_status "HEAD api self before reveal" "$api_head_before" "200"

api_get_first="$(curl -ksS -o "$TMP_DIR/api_get_first.json" -w "%{http_code}" "$api_self")"
assert_status "GET api self first" "$api_get_first" "200"
grep -Fq "$api_secret" "$TMP_DIR/api_get_first.json" || fail "API GET response missing expected secret"

api_head_after="$(curl -ksS -I -o "$TMP_DIR/api_head_after.txt" -w "%{http_code}" "$api_self")"
assert_status "HEAD api self after reveal" "$api_head_after" "404"

echo "[6/6] Health endpoint"
health_status="$(curl -ksS -o "$TMP_DIR/health.json" -w "%{http_code}" "$BASE_URL/_/_/health")"
assert_status "GET /_/_/health" "$health_status" "200"

echo "Smoke test passed for $BASE_URL"
