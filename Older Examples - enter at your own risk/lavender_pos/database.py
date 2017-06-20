import os

from sqlalchemy import create_engine
from sqlalchemy.orm import scoped_session, sessionmaker
from sqlalchemy.ext.declarative import declarative_base

# use a sqlite database file in the current directory
cur_dir = os.path.dirname(os.path.abspath(__file__))
file_name = 'sqlite.db'

# create an engine and session for this user
engine = create_engine('sqlite:///%s/%s' % (cur_dir, file_name),
  convert_unicode=True)
session = scoped_session(sessionmaker(autocommit=False, autoflush=False,
  bind=engine))

# create a model base
Base = declarative_base()
Base.query = session.query_property()


def init_db():
    """
    Initialize the database subsytem.
    """
    # import models here so they'll properly register the metadata;
    # otherwise, import them first before calling init_db()
    from app import models
    Base.metadata.create_all(bind=engine)
