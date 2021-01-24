#!/bin/bash

### Please consult README.md before running this.

###
### config
###

# linux binary dependencies are listed here (except for echo - that is assumed)."
BINS="grep sed curl openssl find cat awk cp reboot ln"

# certificates directory (can be /opt/etc/ssl/certs on *WRT)
CDS="/etc/ssl/certs"

# ca-certificates file
CAS="$CDS/ca-certificates.crt"

# config file
CONFIG="cert-inject.conf"

# ha version data file
HA_VER="ha-version.log"

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
  [ -f "$CDS/${c##*/}" ] && [ ! -L "$CDS/${pem_hash}.0" ] && { $ln -s "$CDS/${c##*/}" "$CDS/${pem_hash}.0" || _WRN "Error creating symlink $pem_hash.0 for $CDS/${c##*/}"; } || _SAY "- ${c##*/} is already linked, skipping."
  _SAY "- $CDS/${c##*/} is linked to $CDS/${pem_hash}.0."

done

# check if we can hit test site securely (in case there's no point running any further)
# also, echo 0 if this is also used for monitoring ssl.
CHECK_SSL_INT && { _SAY "Test site says SSL handshake is passing now, success." || _ERR "SSL Tests are still failing, this should not happen.\n   Please raise an issue on github.\n"; exit 1; }

# check if auto_reboot is set, exit if we don't need to worry about it.
[ -z "$auto_reboot" ] && { _SAY "Auto Reboot is off, exiting."; exit 0; }

# reboot logic: some integrations load before this script runs on a new Core version.
# this is to ensure to make that reboot, assuming ssl trust has just been achieved (and do not do that twice for the same version).
f="/config/.HA_VERSION"
if [ -f "$f" ]; then current_ha_version=`$cat $f` > /dev/null || current_ha_version=""; fi
_SAY "Current HA Version is: $current_ha_version"

# create the version log file in case it does not exist
[ -f "${0%/*}/$HA_VER" ] && last_reboot=`$cat ${0%/*}/$HA_VER` || touch "${0%/*}/$HA_VER"

# if HA runtime version cannot be determined, do not proceed with reboot
[ -z "$current_ha_version" ] && { _SAY "Couldn't determine HA runtime version ($current_ha_version), not rebooting."; exit 0; }

# in case no latest reboot information, add it and reboot
if [ -z "$last_reboot" ]; then
   _SAY "No information on last successful cert inject reboot. Adding data and rebooting.";
   echo "$current_ha_version" > "${0%/*}/$HA_VER" && {
     _SAY "Added, rebooting..."
     $reboot
   } || {
     _SAY "Could not add, not rebooting"
   }
  # whether or not we could add this, we exit successfully at this point (user will need decide to reboot manually).
  exit 0
fi

# let's check if logged version matches running version
a=`echo "$last_reboot" |grep -q "$current_ha_version"` && {
  _SAY "Version is matching, no reboot needed."
} || {
  _SAY "Runtime version ($current_ha_version) differs from logged version ($last_reboot)."
   echo "$current_ha_version" > "${0%/*}/$HA_VER" && {
     _SAY "Updated, rebooting..."
     $reboot
   } || {
     _SAY "Failed adding current version ($current_ha_version) to ${0%/*}/$HA_VER, exiting."
   }
}

exit 0
# eof
