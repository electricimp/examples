import os
basedir = os.path.abspath(os.path.dirname(__file__))

CSRF_ENABLED = True
# TODO: make secret key
SECRET_KEY = 'TODO'

SQLALCHEMY_DATABASE_URI = 'sqlite:///' + os.path.join(basedir, 'sqlite.db')
