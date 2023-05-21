import sys
import requests

host_port = sys.argv[1]
host, port = host_port.split(':')

try:
    requests.get(f"https://{host}:{port}", timeout = 1)
    exit(0)  # Certificate is valid
except requests.exceptions.SSLError:
    exit(1)  # Certificate is invalid
except requests.exceptions.RequestException:
    exit(1)  # Other connection error