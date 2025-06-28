#!/bin/bash

### Please consult README.md before running this.

###
### config
###

function _SAY { [ -z $debug ] || echo -ne "  $1\n"; return 0; }
function _ERR { echo -ne "!!! Error: $1\n"; exit 1; }
function _WRN { echo -ne "??? $1\n"; return 0; }

# validate internal ssl test site - note that test_site could be non-http
function CHECK_SSL_INT {
    a=$(echo | openssl s_client -connect "$test_site" -servername "${test_site%%:*}" 2>/dev/null)
    if [[ $a =~ "Verification: OK" ]]; then return 0; fi
    return 1
}

function CHECK_SSL_INT_INSECURE { 
  a=$(curl -m 2 -sk "$test_site") || return 1
}

function CLEANUP_TEST_SITE_STRING {
  # remove any protocol prefix (http://, postgres://, smtp://, etc.)
  test_site=${test_site#*://}
  # remove any path/query/fragment suffix  
  test_site=${test_site%%/*}
  # remove any userinfo prefix (user:pass@)
  test_site=${test_site##*@}
  # add default port if none specified
  [[ $test_site == *:* ]] || test_site=$test_site:443
}

function BIN_DEPS {
  a=$(update-ca-certificates --help) || { apk add --no-cache ca-certificates || _ERR "Failed to install ca-certificates"; }
  a=$(openssl --version) || { apk add --no-cache openssl || _ERR "Failed to install openssl"; }
  a=$(curl --version) || { apk add --no-cache curl || _ERR "Failed to install curl"; }
  a=$(python3 --version) || { _WRN "Python3 is somehow not installed, turning certifi injection off."; unset certifi; }
}

function CHECK_CERTS {
  [ -d "${0%/*}/certs" ] || _ERR "${0%/*}/certs directory is missing. Please create that and put your .pem, .crt or .cer certificates in it"
  _SAY "The ${0%/*}/certs directory exists"
}

function CHECK_SSL_INT_PY { 
  python3 -c "
import ssl, sys, socket, certifi

host_port = sys.argv[1]
host, port = host_port.split(':')

try:
    # Explicitly use certifi's certificate bundle
    context = ssl.create_default_context(cafile=certifi.where())
    with socket.create_connection((host, int(port)), timeout=1) as sock:
        with context.wrap_socket(sock, server_hostname=host):
            pass  # SSL connection successful
    exit(0)
except ssl.SSLError as e:
    print(f'SSL Certificate validation failed for {host}:{port}', file=sys.stderr)
    print(f'SSL Error: {e}', file=sys.stderr)
    print(f'Using certificate bundle: {certifi.where()}', file=sys.stderr)
    exit(1)
except Exception as e:
    print(f'Connection failed to {host}:{port}', file=sys.stderr)  
    print(f'Error: {e}', file=sys.stderr)
    exit(1)
" "$test_site" || return 1
}

# switch on debug if it's been defined.
a=$(echo "$1" |grep -i -q "debug") && debug="1"
_SAY "\b\bRunning with debug"

# load config
[ -f "${0%/*}/haci.conf" ] && { source "${0%/*}/haci.conf" || _ERR "Failed loading config: haci.conf."; } || _ERR "Config file haci.conf does not exist or no access."
_SAY "Config loaded"

# check dependencies
BIN_DEPS || _ERR "Failed to check dependencies"
_SAY "Dependencies checked"

CHECK_CERTS || _ERR "Failed to check certs directory ${0%/*}/certs, or it's missing .crt/.cer/.pem files"
_SAY "Certs checked"

# backward compatibility for https://this-site vs this-site:port
CLEANUP_TEST_SITE_STRING || _ERR "Failed to cleanup test_site string"
_SAY "Test site string final: $test_site"

# grab all certs in the certs directory
certs=$(find "${0%/*}/certs"/ -type f \( -name "*.crt" -o -name "*.pem" -o -name "*.cer" \)) || _ERR "Find throws error for ${0%/*}/certs"

# alpine linux
CHECK_SSL_INT && _SAY "Linux SSL handshake is passing, not injecting certs" || {
  _SAY "Linux SSL handshake is failing, injecting certs"
  # copy certs to /usr/local/share/ca-certificates and update ca-certificates
  mkdir -p /usr/local/share/ca-certificates || _ERR "Failed to create /usr/local/share/ca-certificates directory"
  _SAY "  Copying certs to /usr/local/share/ca-certificates"
  for cert in $certs; do
    cp -prf "$cert" "/usr/local/share/ca-certificates/" || _ERR "Failed to copy cert $cert to /usr/local/share/ca-certificates"
  done
  _SAY "  Updating ca-certificates"
  update-ca-certificates || _ERR "Failed to update ca-certificates"
  # check SSL trust - should be good now
  CHECK_SSL_INT && _SAY "Test site says Linux SSL handshake is passing now, success." || { 
    _ERR "Linux SSL Tests are still failing, this should not happen.\n   Please raise an issue on github.\n"
    exit 1
  }
}

# python certifi
CHECK_SSL_INT_PY && _SAY "Python SSL handshake is passing, not injecting certs" || {
  _SAY "Python SSL handshake is failing, injecting certs"
  # python will need exact certs, grabbing a list

  certifi_file=$(python3 -m certifi)
  # loop through certs and inject them into python3 certifi
  for cert in $certs; do
    echo "# github.com/miklosbagi/haci $cert $(date +%Y-%m-%d' '%H:%M:%S)" >> $certifi_file || _ERR "Failed to add HACI tag to certifi file $certifi_file"
    a=$(cat "$cert" >> "$certifi_file") || _ERR "Failed to inject cert $cert into python3 certifi $certifi_file"
    _SAY "  Injected cert $cert into python3 certifi ($(python3 -m certifi))"
  done

  # check SSL trust - should be good now
  CHECK_SSL_INT_PY && _SAY "Test site says Python Certifi SSL handshake is passing now, success." || { 
    _ERR "Python Certifi SSL Tests are still failing, this should not happen.\n   Please raise an issue on github.\n"
    exit 1
  }
}

exit 0
# eof
