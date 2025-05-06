#!/bin/bash

set -e  # Exit on error

# Check parameters
if [[ $# -lt 2 || ($1 != "server" && $1 != "client") ]]; then
    echo "Usage: $0 <server|client> <hostname> [USER_ID] [GROUP_ID]"
    exit 1
fi

TYPE=$1
HOSTNAME=$2
USER_ID=$3
GROUP_ID=$4

# Ask where to save the certs
read -p "Enter certificate directory [default: ./certs]: " CERT_DIR
CERT_DIR=${CERT_DIR:-./certs}
mkdir -p "$CERT_DIR"

# Ask for domain name
read -p "Enter domain name [default: example.com]: " DOMAIN
DOMAIN=${DOMAIN:-example.com}

# Extract second-level domain (e.g., example.com -> example)
DOMAIN_PART=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)}')
CA_NAME="${DOMAIN_PART}CA"
CA_KEY="$CERT_DIR/${CA_NAME}.key"
CA_CERT="$CERT_DIR/${CA_NAME}.crt"
CA_CONF="$CERT_DIR/.${CA_NAME}.conf"

# Create CA if not exists
if [[ ! -f "$CA_KEY" || ! -f "$CA_CERT" ]]; then
    echo "Creating new Certificate Authority: $CA_NAME"
    echo "Enter CA certificate information (press Enter to accept defaults):"

    read -p "  Country (C) [IT]: " C
    read -p "  State (ST) [Over The Rainbow]: " ST
    read -p "  Locality (L) [Somewhere]: " L
    read -p "  Organization (O) [Example Org]: " O
    read -p "  Organizational Unit (OU) [Example Department]: " OU
    read -p "  Common Name (CN) [MyRootCA.$DOMAIN]: " CN
    read -p "  Email Address [my.email@$DOMAIN]: " EMAIL

    C=${C:-IT}
    ST=${ST:-Over The Rainbow}
    L=${L:-Somewhere}
    O=${O:-Example Org}
    OU=${OU:-Example Department}
    CN=${CN:-MyRootCA.$DOMAIN}
    EMAIL=${EMAIL:-my.email@$DOMAIN}

    echo "C='$C'"     > "$CA_CONF"
    echo "ST='$ST'"   >> "$CA_CONF"
    echo "L='$L'"     >> "$CA_CONF"
    echo "O='$O'"     >> "$CA_CONF"
    echo "OU='$OU'"   >> "$CA_CONF"
    echo "CN='$CN'"   >> "$CA_CONF"
    echo "EMAIL='$EMAIL'" >> "$CA_CONF"

    CA_SUBJECT="/C=$C/ST=$ST/L=$L/O=$O/OU=$OU/CN=$CN/emailAddress=$EMAIL"

    openssl genrsa -out "$CA_KEY" 4096
    openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days 3650 \
        -out "$CA_CERT" -subj "$CA_SUBJECT"

    chmod 600 "$CA_KEY"
    chmod 644 "$CA_CERT"

    # Set CA_CONF read only
    chmod 444 "$CA_CONF"

    echo "✔ CA '$CA_NAME' successfully created"

    read -p "Do you want to trust this CA system-wide? You can do manually later [y/N]: " TRUST_CA
    TRUST_CA=${TRUST_CA,,}  # Convert to lowercase

    if [[ "$TRUST_CA" == "y" || "$TRUST_CA" == "yes" ]]; then
        echo "🔍 Detecting OS for CA trust installation..."

        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            case "$ID" in
                debian|ubuntu)
                    sudo cp "$CA_CERT" "/usr/local/share/ca-certificates/$CA_NAME.crt"
                    sudo update-ca-certificates
                    echo "✔ CA trusted on Debian/Ubuntu"
                    ;;
                rhel|centos|fedora)
                    sudo cp "$CA_CERT" "/etc/pki/ca-trust/source/anchors/$CA_NAME.crt"
                    sudo update-ca-trust
                    echo "✔ CA trusted on RHEL/CentOS/Fedora"
                    ;;
                arch)
                    sudo cp "$CA_CERT" "/etc/ca-certificates/trust-source/anchors/$CA_NAME.crt"
                    sudo trust extract-compat
                    echo "✔ CA trusted on Arch Linux"
                    ;;
                *)
                    echo "⚠️ Unsupported or unknown distribution: $ID"
                    echo "You can manually install the CA if needed."
                    ;;
            esac
        else
            echo "⚠️ Cannot detect OS. Skipping trust installation."
        fi
    else
        echo "ℹ️ Skipping CA trust setup."
    fi

else
    source "$CA_CONF"
fi



# Generate key and CSR for server/client
SERVICE_CERT_DIR="$CERT_DIR/$HOSTNAME"
mkdir -p "$SERVICE_CERT_DIR"
KEY_FILE="$SERVICE_CERT_DIR/$HOSTNAME.$DOMAIN.$TYPE.key"
CSR_FILE="$SERVICE_CERT_DIR/$HOSTNAME.$DOMAIN.$TYPE.csr"
CRT_FILE="$SERVICE_CERT_DIR/$HOSTNAME.$DOMAIN.$TYPE.crt"
EXT_FILE="$SERVICE_CERT_DIR/$HOSTNAME.$DOMAIN.$TYPE.ext"

openssl genrsa -out "$KEY_FILE" 2048

SUBJECT="/C=$C/ST=$ST/L=$L/O=$O/OU=$OU/CN=$HOSTNAME.$DOMAIN/emailAddress=$EMAIL"
openssl req -new -key "$KEY_FILE" -out "$CSR_FILE" -subj "$SUBJECT"

# Generate extensions
echo "subjectAltName = DNS:$HOSTNAME, DNS:$HOSTNAME.$DOMAIN" > "$EXT_FILE"
if [[ $TYPE == "server" ]]; then
    echo "extendedKeyUsage = serverAuth" >> "$EXT_FILE"
else
    echo "extendedKeyUsage = clientAuth" >> "$EXT_FILE"
fi

# Generate unique serial number
SERIAL=$(od -An -N4 -tu4 < /dev/urandom | tr -d ' ')

# Sign the certificate
openssl x509 -req -in "$CSR_FILE" -CA "$CA_CERT" -CAkey "$CA_KEY" \
    -out "$CRT_FILE" -days 825 -sha256 -extfile "$EXT_FILE" \
    -set_serial "$SERIAL"

# Set permissions
chmod 600 "$KEY_FILE"
chmod 644 "$CRT_FILE"
chmod 644 "$CSR_FILE"

# Optional chown
if [[ -n $USER_ID && -n $GROUP_ID ]]; then
    chown "$USER_ID:$GROUP_ID" "$KEY_FILE" "$CRT_FILE"
fi

echo "✔ $TYPE certificate for $HOSTNAME generated:"
echo "  Key : $KEY_FILE"
echo "  Cert: $CRT_FILE"
