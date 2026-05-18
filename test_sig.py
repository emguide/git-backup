import signal
import sys

def handler(sig, frame):
    print("Handler called!")
    sys.exit(0)

signal.signal(signal.SIGTERM, handler)
signal.signal(signal.SIGINT, handler)

try:
    print("Pausing...")
    signal.pause()
except (KeyboardInterrupt, SystemExit):
    print("Caught KeyboardInterrupt or SystemExit!")
    # handler(None, None)

