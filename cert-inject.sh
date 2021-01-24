#!/bin/bash

### Please consult README.md before running this.

###
### config
###

# linux binary dependencies are listed here (except for echo - that is assumed)."
BINS="grep sed curl openssl find cat awk cp ln"

# certificates directory (can be /opt/etc/ssl/certs on *WRT)
CDS="/etc/ssl/certs"

# ca-certificates file
CAS="$CDS/ca-certificates.crt"

# config file
CONFIG="cert-inject.conf"

###
### functions
###

# comm functions
function _SAY { [ -z $debug ] || echo -ne "  $1\n"; return 0; }
function _ERR { echo "!!! Error: $1"; exit 1; }
function _WRN { echo "??? $1"; return 0; }

# find functions
function FIND_BIN {
  for loc in /bin /usr/bin /usr/local/bin /sbin /usr/sbin /opt/bin /usr/lib; do
      if [ -d "$loc" ]; then if [ -f "$loc/$1" ]; then
         eval "$1"="$loc/$1"; return; fi; fi
  done
  # fail in case there is no sign of that binary in all those directories...
  return 1
}

# validate internal ssl test site
function CHECK_SSL_INT { a=`$curl -m 2 -sIX GET "$test_site"` && return 0 || return 1; }
function CHECK_SSL_INT_INSECURE { a=`$curl -m 2 -sk "$test_site"` && return 0 || return 1; }

###
### exec
###

# find all the bins required.
for bin in $BINS; do FIND_BIN "$bin" || _ERR "Cannot find $bin in PATH or at common locations."; done

# switch on debug if it's been defined.
d=`echo "$1" |grep -i -q "debug"` && debug="1"
_SAY "\b\bRunning with debug"

# load config
[ -f ${0%/*}/$CONFIG ] && { source "${0%/*}/$CONFIG" || _ERR "Failed loading config: $CONFIG."; } || _ERR "Config file $CONFIG does not exist or no access."
_SAY "Config loaded"

# validate test site 1,2
[ -z "$test_site" ] && _ERR "Test site (test_site) is not defined in CONFIG $config"
a=`echo "$test_site" | $grep -q "^https://"` || _ERR "Test site \"$test_site\" is not https://"
_SAY "Test site ($test_site) passed basic validation"

# check if site is up at all
CHECK_SSL_INT_INSECURE || _ERR "The test_side provided "$test_site" in CONFIG doesn't seem to return useful data. Is it up? (try curl -sk $test_site)"
_SAY "Test site returns useful data when hit insecurely"

# check if we can hit test site securely (in case there's no point running any further)
CHECK_SSL_INT && { _SAY "SSL is passing, not injecting anything."; exit 0; }
_SAY "Test site is failing https test, need to inject certs."

# check that the certs we are having are actually certs
[ -d "${0%/*}/certs" ] || _ERR "${0%/*}/certs directory is missing. Please create that and put your .pem, .crt or .cer certificates in it"
_SAY "The ${0%/*}/certs directory exists"

# find all the certs to be added
certs=`$find "${0%/*}/certs"/ -type f \( -name "*.crt" -o -name "*.pem" -o -name "*.cer" \)` || _ERR "Find throws error for ${0%/*}/certs"
[ -z "$certs" ] && _ERR "No certificates were found in ${0%/*}/certs, please place your Root CA and any intermediate CAs in that directory in PEM format."
_SAY "Found certs: \n$certs" |$sed 's#^[\./]./\?#  - #'

# check if ca-certificates file actually exists
[ -f "$CAS" ] || _ERR "Whoops, we need $CAS to exist. Looks like there's no certs at all on this system."
_SAY "Great, $CAS is in place."

# create a backup of the ca-certificates file in case it doesn't exist yet.
[ ! -f "${0%/*}/ca-certificates.crt.backup" ] && { cp "$CAS" "${0%/*}/ca-certificates.crt.backup" && _SAY "Created backup for $CAS as ${0%/*}/ca-certificates.crt.backup" || _WRN "Failed creating backup for $CAS"; }

_SAY "Loading up $CAS data, please be patient..."
# load up all serial/subject from ca-certificates (used to check if cert is already added)
all_certs_data=`$awk -v cmd="$openssl x509 -noout -serial -subject" "/BEGIN/{close(cmd)};{print | cmd}" < "$CAS"` || _ERR "Error loading ca-certificates serial & subject data."
[ -z "$all_certs_data" ] && _ERR "ca-certificates comparison data is empty."

_SAY "Loaded up all ca-certificates data for comparison."

# iterate through the certs to be added
for c in $certs; do
  # validate certificate is pem with openssl
  v=`$openssl x509 -in $c -text -noout >/dev/null 2>&1` || { _WRN "Certificate $c is not a valid pem formatted certificate, skipping."; continue; }
  _SAY "Certificate $c looks valid."

  # load up certificate data for commparison
  this_cert_data=`$awk -v cmd="$openssl x509 -noout -serial -subject" "/BEGIN/{close(cmd)};{print | cmd}" < "$c"` || _ERR "Error $c serial & subject data."

  # check if this cert added already, and do not proceed if so.
  inject=""
  t=`echo "$all_certs_data" |grep -q "$this_cert_data"` && { _SAY "- Certificate is already added, skipping." && inject=1; }

  # load up and push cert
  [ -z $inject ] && {
    this_cert=`$cat $c` || { _WRN "Error reading up $c, skipping."; continue; }
    _SAY "- Pushing $c into ca-certificates..."
    echo -ne "$this_cert\n\n" >> "$CAS" || _WRN "Error pushing $c to $CAS"
    _SAY "- Added $c to ca-certificates"
  }

  # copy cert to certs dir ${a##*/}
  [ ! -f "$CDS/${c##*/}" ] && { cp "$c" "$CDS/" || _WRN "Failed to copy ${c##*/} to /etc/ssl/certs"; } || _SAY "- $CDS/${c##*/} already exists, no copy."
  _SAY "- $CDS/$c is in place"

  # Create pem hash
  pem_hash=`$openssl x509 -hash -noout -in "$c"` || { _WRN "Failed creating pem hash for ${c##*/}, WILL NOT LINK."; continue; }
  _SAY "- PEM hash is: $pem_hash"
  # symlink hash to certs dir (note low risk with .0 here)
  [ -f "$CDS/${c##*/}" ] && [ ! -L "$CDS/${pem_hash}.0" ] && { $ln -s "${c##*/}" "$CDS/${pem_hash}.0" || _WRN "Error creating symlink $pem_hash.0 for $CDS/${c##*/}"; } || _SAY "- ${c##*/} is already linked, skipping."
  _SAY "- $CDS/${c##*/} is linked to $CDS/${pem_hash}.0."

done

# check SSL trust again, fingers crossed all worked fine.
CHECK_SSL_INT && _SAY "Test site says SSL handshake is passing now, success." || { 
  _ERR "SSL Tests are still failing, this should not happen.\n   Please raise an issue on github.\n"
  exit 1
}

exit 0
# eof
