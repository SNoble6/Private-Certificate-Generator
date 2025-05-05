# Private Certificate Generator

This Bash script allows you to create a custom Certificate Authority (CA) and generate server/client certificates signed by it, with optional system-wide trust setup for Linux systems.

## ✨ Features

- Creates a private CA if one doesn't exist
- Generates server or client certificates signed by the CA
- Supports user input for:
  - Output directory
  - Domain name
  - UID and GID for file ownership
- Adds proper certificate extensions (SAN and EKU)
- Optionally installs the CA as a trusted authority for:
  - Debian / Ubuntu
  - RHEL / CentOS / Fedora
  - Arch Linux

## 🛠️ Usage

```bash
./gen_certs_new.sh <server|client> <hostname> [USER_ID] [GROUP_ID]
````

### Examples

```bash
./gen_certs_new.sh server myserver 1000 1000
./gen_certs_new.sh client client1
```

During execution, the script will prompt you to:

* Choose the output directory (default: `./certs`)
* Enter the domain name (default: `example.com`)
* Provide CA certificate details (if creating a new CA)
* Decide whether to trust the CA system-wide

## 🐳 Using with Docker and Microservices

If you're working with microservices in a Docker-based environment, you can take advantage of Docker's DNS resolution to generate certificates for your containers. When using **Docker Compose**, you can set the container name as the `hostname` in the script, and Docker will resolve the service name automatically within the Docker network.

For example, in your `docker-compose.yml`, you could have something like:

```yaml
services:
  web:
    image: mywebapp
    container_name: webserver
    networks:
      - app-network
  api:
    image: myapi
    container_name: apiserver
    networks:
      - app-network
networks:
  app-network:
    driver: bridge
```

In this case, you can run the script for the `web` container as follows:

```bash
./gen_certs_new.sh server webserver
```

This will generate a certificate for `webserver` with the appropriate Subject Alternative Name (SAN) and Extended Key Usage (EKU) for a server certificate. You can then mount the generated certificates into the corresponding containers, ensuring secure communication between your microservices.

## 📁 Output Structure

Typical output under the certificate directory:

```
certs/
├── exampleCA.crt               # CA certificate
├── exampleCA.key               # CA private key
├── .exampleCA.conf             # CA info for re-use
└── myhost/
    ├── myhost.example.com.crt  # Generated certificate
    ├── myhost.example.com.csr  # CSR (Certificate Signing Request)
    └── myhost.example.com.key  # Private key
```

## 🔐 Permissions

* Private keys are stored with `600` permissions
* Certificates and CSRs with `644` permissions
* The CA configuration file is set to read-only (`444`)

## 🐧 Requirements

* Linux with `openssl`
* `sudo` privileges if you want to install the CA as trusted

## ⚠️ Notes

* This script is intended for **Linux only**
* Windows and macOS are **not supported**
* Manual installation is required for CA trust on unsupported platforms

## 📜 License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0). You are free to use, modify, and distribute the software, but any modified versions must also be shared under the same GPL-3.0 license.

If you decide to use this software in your own projects or distribute it, you must make the source code available, even if you modify it. You cannot sell the original code or claim ownership of it.

For more details, please see the [LICENSE](LICENSE) file in this repository.
