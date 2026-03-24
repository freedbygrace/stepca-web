#!/bin/bash
set -e

# ─────────────────────────────────────────────────────────────────────────────
# stepca-web Docker Entrypoint
# Configures local authentication on container startup using env vars:
#   ADMIN_USER     (default: admin)
#   ADMIN_PASSWORD (default: admin)
#   AUTH_BACKEND   (default: local)
# Idempotent - safe to run on every container start.
# ─────────────────────────────────────────────────────────────────────────────

ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
AUTH_BACKEND="${AUTH_BACKEND:-local}"
BACKEND_FILE="/app/app/libs/auth/local_backend.py"
MARKER_FILE="/app/.auth_configured"

configure_local_auth() {
    # Skip if already configured with the same password
    if [[ -f "$MARKER_FILE" ]] && [[ "$(cat "$MARKER_FILE" 2>/dev/null)" == "${ADMIN_USER}:${ADMIN_PASSWORD}" ]]; then
        echo "[entrypoint] Local auth already configured for user '${ADMIN_USER}'."
        return 0
    fi

    echo "[entrypoint] Configuring local auth backend (user: ${ADMIN_USER})..."

    python3 << PYEOF
from werkzeug.security import generate_password_hash

admin_user = "${ADMIN_USER}"
admin_password = "${ADMIN_PASSWORD}"
password_hash = generate_password_hash(admin_password)

backend_code = f"""from .base import AuthBackend
from werkzeug.security import check_password_hash

USERS = {{
    '{admin_user}': {{
        'id': '{admin_user}',
        'username': '{admin_user}',
        'attributes': {{'role': 'admin'}},
        'password_hash': '{password_hash}'
    }},
}}

class LocalAuthBackend(AuthBackend):
    def __init__(self, config):
        self.config = config

    def authenticate(self, username, password):
        user = USERS.get(username)
        if user and check_password_hash(user.get('password_hash', ''), password):
            return {{'id': user['id'], 'attributes': user.get('attributes', {{}})}}
        return None

    def get_user(self, user_id):
        user = USERS.get(user_id)
        if user:
            return {{'id': user['id'], 'attributes': user.get('attributes', {{}})}}
        return None
"""

with open("${BACKEND_FILE}", "w") as f:
    f.write(backend_code)

print(f"[entrypoint] Local auth backend written with user '{admin_user}'.")
PYEOF

    # Write marker so we don't regenerate on every restart
    echo "${ADMIN_USER}:${ADMIN_PASSWORD}" > "$MARKER_FILE"
}

# Only configure if using local auth backend
if [[ "$AUTH_BACKEND" == "local" ]]; then
    configure_local_auth
fi

# Execute the original CMD (python run.py)
exec "$@"
