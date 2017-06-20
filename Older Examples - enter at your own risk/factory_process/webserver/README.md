Quickstart Explanation
----------------------

The following is an explanation of how this Quickstart was created so you can use it as a guide in creating your own Quickstarts.

* Config File: Because Pagoda Box needs a different config file than a local version of the site, we created a new directory in the root of the project called "pagoda" and created a pagoda version of the config file there. Then we created an After Build deploy hook in the Boxfile that moved that file from pagoda/database.php to application/config/database.php. Also, in place of the static database credentials, we used the auto-created environment variables.

<pre>
    <code>
        after_build:
            - "mv pagoda/database.php application/config/database.php"
    </code>
</pre>

* Database Component: An empty database was created by adding a db component to the Boxfile.

<pre>
   <code>
        db1:
            name: devices
   </code>
</pre>

* Database Import: To migrate the database tables that were created locally, we created a Before Deploy hook that would import an sql file. But since that import should only happen on the first deploy and not subsequent deploys, we placed it in the Boxfile.install file.

<pre>
    <code>
        - "mysql -h $DB1_HOST --port $DB1_PORT -u $DB1_USER -p$DB1_PASS $DB1_NAME &lt; /var/www/pagoda/ci-devices-setup.sql"
    </code>
</pre>
