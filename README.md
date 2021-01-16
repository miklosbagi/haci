# Home Assistant Certificate Injector
This is prototype code for injecting self-signed certificates into Home Assistant.

## Is this for me?
In case all the following statements are true when you are:
- running Home Assistant OS or Home Assistant (Core) container
- having self-signed certificates
- running services with those self-signed certificates
- looking to integrate those services with Home Assistant
- not a fan of skipping certificate validation (e.g.: ```curl -k```)
- running into the "I can't make Home Assistant trust my certificates" problem

You **do not need this** when you are:
- looking to put Home Assistant behind SSL (e.g. https://hass.lan)

## Quickstart
### Prerequisites
- Shell access to your Home Assistant instance (Physical, ssh, terminal or even the shell provided in the vscode addon).
- The certificates you are looking to get trusted in PEM format (.pem, .crt, .cer)
- A website running behind a self-signed certificate (for validating results)

### Step-by-step
1. Login to Home Assistant Core via SSH
2. Navigate to a directory that is available to both Home Assistant Core and your SSH (e.g. /config)
3. Clone this repository with ```git clone```
4. In the cloned directory, ```cp cert-inject.conf.sample cert-inject.conf```
5. Add the test site: ```test-site="https://my-nextcloud.lan"``` to cert-inject.conf
6. Place your PEM formatted certificates into the ```certs``` directory
7. Make sure permissions are correct: ```chmod 700 cert-inject.sh```

At this point, you can run the script with ```./cert-inject.sh``` without any parameters to make the necessary changes. Please note thought that the normal operation is quiet (so we can run it in the background properly), but there is a debug option implemented where each action is confirmed: ```./cert-inject.sh debug```.

It is recommended that you first run with debug.

### Creating a certificate trust monitor sensor
Example for configuration.yaml:
```
### Home Assistant Cert Injector
sensor:
  - platform: command_line
    name: "Cert Injector"
    command: "/config/cert_injector/cert-inject.sh && echo 1 || echo 0"
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
Yes, the ca-certificates.crt file gets backed up the first time you run this script. It will be called ca-certificates.crt.backup - just copy this back to /etc/ssl/certs/ and overwrite the modified one to revert all changes back to normal.

```Any binary dependencies to worry about?```  
No. There is reliance on basic linux tools and openssl - all binary dependencies are validated on script start, so you don't end up with a half-baked solution.

```Why is this not an integration?```  
- According to the Home Assistant folks, there isn't a lot of people with this exact need, so did not bother
- Only applicable to Home Assistant OS and Core container, so there are some obvious limitations in usage.

```Is this maintained?```  
I can commit to maintaining it for as long as run Home Assistant OS myself - should that change, this line will change.

## Legal
Keeping this short:
- Provided as-is. No warranty: if you find a way to blow up your house by running this, blame is on you.
- For individual: use it, run it, change it, share the changes, free as freedom.
- For business: do not.
