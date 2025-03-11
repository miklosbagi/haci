# HACI: Home Assistant Certificate Injector

[![HACI on HASS latest](https://github.com/miklosbagi/haci/actions/workflows/hass-latest-haci-test.yml/badge.svg?kill_cache=1)](https://github.com/miklosbagi/haci/actions/workflows/hass-latest-haci-test.yml) [![HACI on HASS stable](https://github.com/miklosbagi/haci/actions/workflows/hass-stable-haci-test.yml/badge.svg?kill_cache=1)](https://github.com/miklosbagi/haci/actions/workflows/hass-stable-haci-test.yml) [![HACI on HASS rc](https://github.com/miklosbagi/haci/actions/workflows/hass-rc-haci-test.yaml/badge.svg?kill_cache=1)](https://github.com/miklosbagi/haci/actions/workflows/hass-rc-haci-test.yaml) [![HACI on HASS dev](https://github.com/miklosbagi/haci/actions/workflows/hass-dev-haci-test.yml/badge.svg?kill_cache=1)](https://github.com/miklosbagi/haci/actions/workflows/hass-dev-haci-test.yml) [![HACI on HASS 2025.1](https://github.com/miklosbagi/haci/actions/workflows/hass-202501-haci-test.yml/badge.svg)](https://github.com/miklosbagi/haci/actions/workflows/hass-202501-haci-test.yml) [![HACI on HASS 2024.1 Reference](https://github.com/miklosbagi/haci/actions/workflows/hass-202401-haci-test.yml/badge.svg?kill_cache=1)](https://github.com/miklosbagi/haci/actions/workflows/hass-reference-haci-test.yml) [![HACI on HASS 2023.1](https://github.com/miklosbagi/haci/actions/workflows/hass-202301-haci-test.yml/badge.svg?kill_cache=1)](https://github.com/miklosbagi/haci/actions/workflows/hass-202301-haci-test.yml)

This script injects self-signed certificates into Home Assistant, ensuring SSL trust for services protected by those certificates. It patches both the Linux certificates inside the `homeassistant` container on HassOS and Python's `certifi` package.  
By setting up a command-line sensor (example below), you can automate SSL trust monitoring and re-inject certificates if they break.

## Is this for you?
Use HACI if **all** the following apply:
Yes, in case your response to all of the following statements are true:
- You're running Home Assistant OS or Home Assistant (Core) in a container.
- You already have self-signed certificates.
- You rely on services protected by these certificates.
- You prefer not to skip certificate validation (e.g., `curl -k` or setting `verify_ssl: false`).
- You're struggling to make Home Assistant trust your certificates. 

You **DO NOT need HACI** to simply enable SSL (e.g., https://hass.lan with Let's Encrypt).  
HACI is for making HA trust your Certificate Authority (CA).

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
```
### Home Assistant Cert Injector
sensor:
  - platform: command_line
    name: "HACI"
    command: "/share/haci/haci.sh && echo 1 || echo 0"
    device_class: safety
    payload_on: 0
    payload_off: 1
```

## FAQ
```OpenSSL Binary is not found!```
Please be aware that as of HASSOS 2022.6.2, the openssl binary has been removed. This issue has been addressed in [#4](/../../issues/4), so cloning the latest HACI should fix this.

```Is this limited to internal services?```  
No. Just set the test site to an external https site - the point is to trust the ssl that site uses.

```Is it safe to add this script as a sensor?```  
Relatively yes. There are a few measures to avoid certificates linked or added more than once.

```Does this solution resist Home Assistant Core updates?```  
No, and yes.  
No, as an update is expected to overwrite the certificates directory and sort of reset any changes made to them.  
Yes, as if you set this script as a sensor, the changes are made the first time it's detected that SSL trust have started failing.
Also, all you need to do is re-run the script should trust be lost, and it's highly likely that it fixes the issue(s).

```Is there a backup created?```  
Yes, for both the /etc/ssl/certs/ca-certificates.crt and /usr/local/lib/python\<runtime_version\>/site-packages/certifi/cacert.pem files are backed up (with a .backup suffix) to HACI's runtime directory. Worst case scenario is that you have to SSH back in and overwrite the original files with the backups.

```Any binary dependencies to worry about?```  
No. There is reliance on basic linux tools and openssl - all binary dependencies are validated on script start, so you don't end up with a half-baked solution.

```Why is this not an integration?```  
- According to the Home Assistant folks, there isn't a lot of people with this exact need, so did not bother
- Only applicable to Home Assistant OS and Core container, so there are some obvious limitations in usage.

```Is this maintained?```  
I can commit to maintaining HACI for as long as I keep running Home Assistant OS myself.  
Should that change, this line will change.

```The XYZ integration says SSL is still not trusted```  
You may want to enable the certifi integration in config and re-run HACI - some integrations rely on Python's Certifi trust chain, and thus adding your certs to linux only will not help.
Also, please note that some anomalies are expected right after upgrading the Core. Thing is, some of your integrations may run before ```haci``` does its magic, and may stuck in a false state until restarted.

```I have ran this in *** console/terminal and it does not seem to work```  
Keep in mind that addons like SSH/Terminal and VSCode run in their own dockers. While certain elements (such as /config) are shared, the /etc/ssl/certs we need is a part of the homeassistant container, as that is the one executing the command_line sensors, python scripts, etc.  
The sensor example above fixed this, however, for running this manually, you have to get into a position to launch ```docker exec -it homeassistant /bin/bash``` successfully. 

```Can I run this at Home Assistant Startup?```  
Yes, in fact that is what I'm doing. Every time 

```Can I make Home Assistant trust my MITM proxy certificates via HACI?```
Yes, Charles Proxy, MITM Proxy or Cisco Umbrella should all work now.

```I'm tryin to use HACI with certifi enabled, and getting this error: ModuleNotFoundError: No module named 'distutils.util'```
Likely you are not running haci inside the ```homeassistant``` container - please note that vscode, terminal / ssh addons live in their own containers, there can be a few differences in installed py modules.

## Thanks
- arfoll, mateuszdrab for their report, and support in resolving [#4](/../../issues/4)

## Legal
Keeping this short:
- Provided as-is. No warranty: if you find a way to blow up your house with this, don't point fingers.
- For individual: use it, run it, change it, share the changes, free as freedom.
- For business: do not.
