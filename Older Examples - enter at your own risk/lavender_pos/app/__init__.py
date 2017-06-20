import flask
import flask.ext.bcrypt as bcrypt
import flask.ext.login as login
import forms
import json
import models
import database as db
import re
import random
import requests
import string

app = flask.Flask(__name__)
app.config.from_object('config')
app.debug = True

login_manager = login.LoginManager()
login_manager.init_app(app)

bcrypt = bcrypt.Bcrypt(app)
db.init_db()


@app.route('/', methods=['GET', 'POST'])
def index():
    if login.current_user.is_authenticated():
        return login.redirect('/dashboard')

    # Create the forms
    sign_up_form = forms.SignUpForm()
    sign_in_form = forms.SignInForm()

    if flask.request.method == 'POST' and sign_up_form.validate_on_submit():
        new_user = models.User(
           first_name=sign_up_form.first_name.data,
           last_name=sign_up_form.last_name.data,
           email=sign_up_form.email.data,
           password=bcrypt.generate_password_hash(sign_up_form.password.data),
        )

        db.session.add(new_user)
        db.session.commit()

        return flask.redirect(flask.url_for('dashboard'))

    if flask.request.method == 'POST' and sign_in_form.validate_on_submit():
        user = models.User.query.filter(
            models.User.email == sign_in_form.user_email.data).first()
        login.login_user(user)
        if (bcrypt.check_password_hash(user.password,
                sign_in_form.user_password.data)):
            return flask.redirect(flask.url_for('dashboard'))

    return flask.render_template('home.epy', sign_up_form=sign_up_form,
        sign_in_form=sign_in_form, user=login.current_user)


@app.route('/log-out')
@login.login_required
def log_out():
    login.logout_user()
    return flask.redirect('/')


@login_manager.user_loader
def load_user(id):
    return models.User.query.get(int(id))


@login_manager.unauthorized_handler
def unauthorized():
    return flask.redirect('/')


@app.route('/dashboard', methods=['GET', 'POST'])
@login.login_required
def dashboard():
    transactions_data = []
    transactions = models.Transaction.query.filter(models.Transaction.user_id
            == login.current_user.id)

    # Format each transaction into a managable array of dictionaries
    for transaction in transactions:
        transactions_data.append({
            'company': models.Vendor.query.filter(models.Vendor.id ==
                transaction.company).first().name,
            'amount': transaction.amount,
            'time': transaction.timestamp.strftime("%I:%M%p on <br />%B %d, %Y")
        })

    return flask.render_template('dashboard.epy', user=login.current_user,
            transactions=transactions_data)


@app.route('/purchase', methods=['GET', 'POST'])
@login.login_required
def purchase():
    # Create the form
    purchase_form = forms.PurchaseForm()

    # If a POST request
    if flask.request.method == 'POST' and purchase_form.validate_on_submit():
        pending_transaction = models.PendingTransaction.query.filter(
                models.PendingTransaction.barcode == 
                purchase_form.barcode.data)

        # If not found, we have an error - we would also confirm payment here
        if pending_transaction.count() < 1:
          data = {
              'barcode': pending_transaction.barcode,
              'status': 'fail'
          }
        else:
          pending_transaction = pending_transaction.first()

          # Update the status of the transaction
          pending_transaction.status = 2;

          # Create a transaction
          new_transaction = models.Transaction(
              user_id=login.current_user.id,
              company=pending_transaction.company,
              amount=pending_transaction.amount
          )
          db.session.add(new_transaction)
          db.session.commit()

          data = {
              'barcode': pending_transaction.barcode,
              'status': 'success'
          }

        # Let the Vendor agent know that the item has been paid for
        vendor = models.Vendor.query.filter(models.Vendor.id ==
            pending_transaction.company).first()
        data['secret'] = vendor.secret
        url = vendor.agent_url + '/dispense'
        headers = {'Content-type': 'application/json', 'Accept': 'text/plain'}
        r = requests.post(url, data=json.dumps(data), headers=headers)

        # Redirect to dashboard
        return flask.redirect(flask.url_for('dashboard'))

    # If not a post request
    # Create barcode and update form
    i2of5_code = ''.join(random.choice(string.digits) for x in range(10))
    purchase_form = forms.PurchaseForm(barcode=i2of5_code)

    # Add to list of pending transactions
    new_pending_transaction = models.PendingTransaction(
        user_id=login.current_user.id,
        barcode=i2of5_code 
    )
    db.session.add(new_pending_transaction)
    db.session.commit()

    # Get image URL
    url = 'http://www.barcodes4.me/barcode/i2of5/' + \
        i2of5_code + '.jpg'
    
    return flask.render_template('purchase.epy', user=login.current_user,
            purchase_form=purchase_form, barcode=i2of5_code, img_url=url)


@app.route('/api/web/polling-check-scan', methods=['POST'])
@login.login_required
def polling_check_scan():
    pending_transaction = models.PendingTransaction.query.filter(
            models.PendingTransaction.barcode == 
            flask.request.json['barcode'])

    # Check if this barcode actually exists
    if pending_transaction.count() < 1:
        return json({ 'error': 'Unknown barcode.' })
    else:
        pending_transaction = pending_transaction.first()

    if pending_transaction.status != 0:
        company_name = models.Vendor.query.filter(models.Vendor.id ==
            pending_transaction.company).first().name
    else:
        company_name = None

    return json.dumps({
        'status': pending_transaction.status,
        'amount': pending_transaction.amount,
        'company': company_name
    })


@app.route('/api/web/cancel-purchase', methods=['POST'])
@login.login_required
def cancel_purchase():
    pending_transaction = models.PendingTransaction.query.filter(
            models.PendingTransaction.barcode == 
            flask.request.json['barcode'])

    # Check if this barcode actually exists
    if pending_transaction.count() < 1:
        return json({ 'error': 'Unknown barcode.' })
    else:
        pending_transaction = pending_transaction.first()

        vendor = models.Vendor.query.filter(models.Vendor.id ==
            pending_transaction.company)

        data['secret'] = vendor.secret
        data['barcode'] = flask.request.json['barcode']
        url = vendor.agent_url + '/cancel'
        headers = {'Content-type': 'application/json', 'Accept': 'text/plain'}
        r = requests.post(url, data=json.dumps(data), headers=headers)


@app.route('/api/agent/claim-barcode', methods=['POST'])
def claim_barcode():
    pending_transaction = models.PendingTransaction.query.filter(
            models.PendingTransaction.barcode == 
            flask.request.json['barcode'])
    
    # Check if barcode actually exists
    if pending_transaction.count() < 1:
        return json.dumps({
            'result': 'Unknown barcode.'
        })
    else:
        # Get the first response
        pending_transaction = pending_transaction.first()

        # Find the vendor
        vendor = models.Vendor.query.filter(models.Vendor.secret ==
            flask.request.json['secret'])
        if vendor.count() < 1:
          return json.dumps({
            'result': 'Unknown vendor.'
          })
        else:
          pending_transaction.status = 1;
          pending_transaction.amount = flask.request.json['amount']
          pending_transaction.company = vendor.first().id 
          db.session.commit()
          return json.dumps({
              'result': 'Success!'
          })


if __name__ == '__main__':
    app.run()
