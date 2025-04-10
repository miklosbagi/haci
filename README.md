# HACI: Home Assistant Certificate Injector

[![HACI on HASS latest](https://github.com/miklosbagi/haci/actions/workflows/hass-latest-haci-test.yml/badge.svg?kill_cache=1)](https://github.com/miklosbagi/haci/actions/workflows/hass-latest-haci-test.yml) [![HACI on HASS stable](https://github.com/miklosbagi/haci/actions/workflows/hass-stable-haci-test.yml/badge.svg?kill_cache=1)](https://github.com/miklosbagi/haci/actions/workflows/hass-stable-haci-test.yml) [![HACI on HASS rc](https://github.com/miklosbagi/haci/actions/workflows/hass-rc-haci-test.yaml/badge.svg?kill_cache=1)](https://github.com/miklosbagi/haci/actions/workflows/hass-rc-haci-test.yaml) [![HACI on HASS dev](https://github.com/miklosbagi/haci/actions/workflows/hass-dev-haci-test.yml/badge.svg?kill_cache=1)](https://github.com/miklosbagi/haci/actions/workflows/hass-dev-haci-test.yml) [![HACI on HASS 2025.1](https://github.com/miklosbagi/haci/actions/workflows/hass-202501-haci-test.yml/badge.svg)](https://github.com/miklosbagi/haci/actions/workflows/hass-202501-haci-test.yml) [![HACI on HASS 2024.1 Reference](https://github.com/miklosbagi/haci/actions/workflows/hass-202401-haci-test.yml/badge.svg?kill_cache=1)](https://github.com/miklosbagi/haci/actions/workflows/hass-reference-haci-test.yml) [![HACI on HASS 2023.1](https://github.com/miklosbagi/haci/actions/workflows/hass-202301-haci-test.yml/badge.svg?kill_cache=1)](https://github.com/miklosbagi/haci/actions/workflows/hass-202301-haci-test.yml)

This script injects self-signed certificates into Home Assistant, ensuring SSL trust for services protected by those certificates. It patches both the Linux certificates inside the `homeassistant` container on HassOS and Python's `certifi` package.  
By setting up a command-line sensor (example below), you can automate SSL trust monitoring and re-inject certificates if they break.  

## Is this for you?
Use HACI if **all** the following apply:
Yes, in case your response to all of the following statements are true:
- You're running Home Assistant OS
- You already have self-signed certificates.
- You rely on services protected by these certificates.
- You prefer not to skip certificate validation (e.g., `curl -k` or setting `verify_ssl: false`).
- You're struggling to make Home Assistant trust your certificates. 

You **DO NOT need HACI** to simply enable SSL (e.g., https://hass.lan with Let's Encrypt).  
HACI is for making HA trust your Certificate Authority (CA).

Please note that for the docker version of home-assistant (Home Assistant **Container**), there's a much easier trick: please take a look at [ca-init-container](https://github.com/miklosbagi/ca-init-container) to see an example on how certs can be dynamically volume mapped 😅

## Quickstart
### Prerequisites
- Shell access to your Home Assistant instance (SSH, physical terminal, or VSCode add-on shell).
- Your self-signed certificates in PEM format (`.pem`, `.crt`, `.cer`).
- A self-signed HTTPS website to test results.

### Step-by-step
1. **Access Home Assistant Core via SSH.**
1. **Navigate to a shared directory (accessible by both Home Assistant Core and SSH, e.g., `/share`).**
1. **Clone this repository:**
   ```console
   git clone git@github.com:miklosbagi/haci.git
   ```
1. **Create a config file:**
   ```console
   cp haci.conf.sample haci.conf
   ```
1. **Add the following to `haci.conf`:**
   ```ini
   test-site="https://my-nextcloud.lan"
   ```
1. **(Optional) Patch Python Certifi CA certs:  
   Add the following to `haci.conf`:**  
   ```ini
   certifi="yes"
   ```
1. **Place your certificates** inside the `certs` directory
1. **Ensure proper script permissions:**
    ```console
   chmod 700 haci.sh
    ```

### Running the script
Run the script with:  
```console
./haci.sh
```

The script runs silently by default for background execution. For debugging, use:
```console
./haci.sh debug
```

**Important**: You must run this inside the `homeassistant` container. Running from SSH add-ons or VSCode will not work.

### Creating a certificate trust monitor sensor (optional)
Example for configuration.yaml:
```yaml
### Home Assistant Cert Injector
sensor:
  - platform: command_line
    name: "HACI"
    command: "/share/haci/haci.sh && echo 1 || echo 0"
    device_class: safety
    payload_on: 0
    payload_off: 1
```

[Please take a look at our FAQ in Wiki](https://github.com/miklosbagi/haci/wiki/FAQ)

## Thanks
- arfoll, mateuszdrab for their report, and support in resolving [#4](/../../issues/4)

## Legal
Keeping this short:
- Provided as-is. No warranty: if you find a way to blow up your house with this, don't point fingers.
- For individual: use it, run it, change it, share the changes, free as freedom.
- For business: do not.
