from flask.ext.wtf import Form, TextField, PasswordField, IntegerField, HiddenField
from flask.ext.wtf import Required, Regexp, EqualTo


class SignUpForm(Form):
    first_name = TextField('First Name', validators=[Required()])
    last_name = TextField('Last Name', validators=[Required()])
    email = TextField('Email', validators=[Required()])

    password = PasswordField('Password', validators=[Required(),
        EqualTo('password_confirm', message='Passwords must match.')])
    password_confirm = PasswordField('Password (again)',
        validators=[Required()])


class SignInForm(Form):
    user_email = TextField('Email', validators=[Required()])
    user_password = PasswordField('Password', validators=[Required()])

class PurchaseForm(Form):
    barcode = HiddenField('barcode')
