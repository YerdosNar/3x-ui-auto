#!/usr/bin/env bash

DOM_NAME=$1
ROUTE=$2
ADMIN_NAME=$3
HASH_PW=$4
PORT=$5
BE_PORT=$6

if [[ -z "$DOM_NAME" || -z "$ROUTE" || -z "$ADMIN_NAME" || -z "$HASH_PW" || -z "$PORT" || -z "$BE_PORT" ]]; then
    echo "Usage: $0 <DOMAIN> <ROUTE> <ADMIN_NAME> <HASH_PW> <PORT> <BACKEND_PORT>"
    exit 1
fi

cat > Caddyfile <<EOF
$DOM_NAME {
	# Compress responses
	encode gzip

	# Enforce modern TLS
	tls {
		protocols tls1.3
	}

	# Security headers for all responses
	header {
		# Pass through specific headers to the backend
		header_up Authorization {>Authorization}
		header_up Content-Type {>Content-Type}

		# Security policies for the browser
		Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
		X-Content-Type-Options nosniff
		X-Frame-Options SAMEORIGIN
		Referrer-Policy strict-origin-when-cross-origin

		# Hide server software details
		-Server
		-X-Powered-By
	}

	# Route 1: Secure and proxy the admin panel
	route /$ROUTE* {
		basic_auth {
			$ADMIN_NAME $HASH_PW
		}
		# BEST PRACTICE: Use localhost if 3x-ui is on the same server
		reverse_proxy localhost:$BE_PORT
	}

	# Route 2: Handle client WebSocket connections for the proxy endpoint
	route /api/v1* {
		# IMPORTANT: Use the actual port your x-ui inbound is listening on for WebSockets
		reverse_proxy localhost:$PORT
	}

	# Route 3 (Fallback): Deny all other requests with a generic 404
	route {
		respond "Not found!" 404
	}
}
EOF
