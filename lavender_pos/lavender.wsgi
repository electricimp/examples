import sys
sys.path.append('/var/www/lavender')

activate_this = '/var/www/lavender/venv/bin/activate_this.py'
execfile(activate_this, dict(__file__=activate_this))

from app import app as application
