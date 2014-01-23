import datetime
from database import Base
from sqlalchemy import Column, String, Integer, ForeignKey, DateTime, Float


class User(Base):
    __tablename__ = 'users'

    id = Column(Integer, primary_key=True)
    first_name = Column(String(255))
    last_name = Column(String(255))
    email = Column(String(255), index=True, unique=True)
    password = Column(String(255))

    def get_id(self):
        """
        Callback for Flask-Login. Represents that unique ID of a given user
        object. It is unicoded as per specification.

        Returns: the unique ID of an object
        """
        return unicode(self.id)

    def is_anonymous(self):
        """
        Callback for Flask-Login. Default to False - we don't deal with any
        anonymous users.

        Returns: False
        """
        return False

    def is_active(self):
        """
        Callback for Flask-Login. Default to True - we don't deal with
        non-active users.

        Returns: True
        """
        return True

    def is_authenticated(self):
        """
        Callback for Flask-Login. Should return True unless the object
        represents a user should not be authenticated.

        Returns: True because all objects should be authenticated
        """
        return True


class PendingTransaction(Base):
    __tablename__ = 'pending_transactions'

    id = Column(Integer, primary_key=True)
    barcode = Column(String(10))
    user_id = Column(Integer, ForeignKey('users.id'))
    timestamp = Column(DateTime, nullable=False, default=datetime.datetime.now())
    # Status: 0 - default, 1 - scanned, 2 - claimed
    status = Column(Integer, default=0)
    company = Column(Integer, ForeignKey('vendors.id'))
    amount = Column(Float)


class Transaction(Base):
    __tablename__ = 'transactions'

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    company = Column(Integer, ForeignKey('vendors.id'))
    amount = Column(Float)
    timestamp = Column(DateTime, nullable=False, default=datetime.datetime.now())

class Vendor(Base):
    __tablename__ = 'vendors'

    id = Column(Integer, primary_key=True)
    name = Column(String(255))
    agent_url = Column(String(255))
    secret = Column(String(255))
