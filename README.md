# Home Assistant Certificate Injector
> :warning: Please be aware that as of HASSOS 2022.7, the openssl binary has been moved, rendering HACI unable to fulfill its purpose. Please consult [#4](/../../issues/4) for additional details.

This is prototype code for injecting self-signed certificates into Home Assistant.  
Setting up as a command_line sensor (example below) can achieve SSL trust monitoring and automated cert-inject in case it breaks.  

## Is this for me?
Yes, in case your response to all of the following statements are true:
- running Home Assistant OS or Home Assistant (Core) container
- already have self-signed certificates
- you rely on services protected by those certificates
- not a fan of skipping certificate validation (e.g.: ```curl -k``` or setting verify_ssl to false)
- running into the "I can't make Home Assistant trust my certificates" problem

You **definitely do not need this** to have Home Assistant behind SSL (e.g. https://hass.lan)

## Quickstart
### Prerequisites
- Shell access to your Home Assistant instance (Physical, ssh, terminal or even the shell provided in the vscode addon).
- The certificates you are looking to get trusted in PEM format (.pem, .crt, .cer)
- A website running behind a self-signed certificate (for validating results)

### Step-by-step
1. Login to Home Assistant Core via SSH
1. Navigate to a directory that is available to both Home Assistant Core and your SSH (e.g. /share)
1. Clone this repository: ```git clone git@github.com:miklosbagi/haci.git```
1. In the cloned directory, ```cp haci.conf.sample haci.conf```
1. Add the test site: ```test-site="https://my-nextcloud.lan"``` to haci.conf
1. Add ```certifi=yes``` to haci.conf in case you need Python Certifi cacert.pem patched too (otherwise only linux certs will be added)
1. Place your PEM formatted certificates into the ```certs``` directory
1. Make sure permissions are correct: ```chmod 700 haci.sh```

At this point, you can run the script with ```./haci.sh``` without any parameters to make the necessary changes. Please note thought that the normal operation is quiet (so we can run it in the background properly), but there is a debug option implemented where each action is confirmed: ```./haci.sh debug```.

**It is recommended that you first run with debug.**

Keep in mind though that you have to run this inside the ```homeassistant``` container. Running in any installed terminal/ssh addion will likely not lead to success.

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


## Legal
Keeping this short:
- Provided as-is. No warranty: if you find a way to blow up your house with this, don't point fingers.
- For individual: use it, run it, change it, share the changes, free as freedom.
- For business: do not.
