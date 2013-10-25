# Set the path
import os
import sys
sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from flask.ext.script import Manager, Server
from app import app

manager = Manager(app)

# Turn on debugger and reloader by default
manager.add_command("runserver", Server(
  use_debugger=True,
  use_reloader=True,
  host="0.0.0.0")
)

if __name__ == "__main__":
    manager.run()
