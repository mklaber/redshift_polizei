<img src="https://s3.amazonaws.com/amg-public/github/polizei.png" align="right" alt="Redshift Polizei ('Police')" />
Redshift Polizei ("Police")
================

Sinatra app for monitoring a Redshift cluster. Built using [Twitter Bootstrap](http://getbootstrap.com/), [Font Awesome](http://fortawesome.github.io/Font-Awesome/) and duck tape.

Setup
---------------------
```
bundle install
cp config/database.sample.yml config/database.yml
cp config/auth.sample.yml config/auth.yml
cp config/aws.sample.yml config/aws.yml
cp config/cache.sample.yml config/cache.yml
cp config/mail.sample.yml config/mail.yml
cp config/polizei.sample.yml config/polizei.yml
```

Configuration
---------------------
1. Configure PostgreSQL and Redhsift database connections in `config/database.yml`
  - run `rake db:setup`
2. Configure OAuth authentication in `config/auth.yml`
  - Google
    - provider: google_oauth2
    - Retrieve Client ID credentials from https://console.developers.google.com
      - Redirect URIs: {host}/auth/google_oauth2/callback
      - Javascript Origins: {host}
3. Configure AWS credentials in `config/aws.yml`
4. Configure the cache in `config/cache.yml`
  - ActiveRecord
    - Uses the configured primary ActiveRecord database connection as a cache
    - type: activerecord
    - table: {full model class name}
  - DynamoDB
    - uses AWS DynamoDB as a cache
    - type: dynamodb
    - table: {table name}
5. Set the mail settings in `config/mail.yml`
  - All settings will be directly injected into Pony.options
6. Set the general application settings in `config/polizei.yml`

Reports
---------------------
1. Running Queries
Displays currently executing queries on your RedShift cluster. Always retrieved uncached from system table 'stv_inflight'.
2. Audit Log
Shows queries which were run on the cluster in the past (by default max 30 days). Retrieved from Postgres database and system table 'SVL_STATEMENTTEXT'. The redshift audit logs are parsed regularly by a cron job to fill the pg database. All queries run after the last available audit log are retrieved uncached from the system table 'svl_statementtext'. The audit log parser can be manually trigger by running `rake redshift:auditlog:import` (see [Data Acquisition](#data-acquisition) below).
3. Tables
Displays size, keys, skew and more for all tables. Read from system tables, then saved in Postgres from where the informations is retrieved to display it. Automatically updated via cronjob. Manually updateable with `rake redshift:tablereports:update` (see [Data Acquisition](#data-acquisition) below) or through the Update button in the web frontend.
4. Permissions
Displays permissions users or groups have on tables. Retrieved from system tables and cached in Permissions table in Postgres.
5. Disk Space
Retrieved uncached from CloudWatch using the 'PercentageDiskSpaceUsed' metric.
6. Exports
Job details are saved and queued in the pg database. Background processes retrieve queued jobs and execute their queries on the cluster, saving the results to S3.

Data Acquisition
---------------------
All cached and generated data can be updated using `rake reports:update`. This takes quite a long time if there are a lot of audit logs to be parsed. This command can be used to update cached data before it is regularly updated or to precache on new deployments. Aborting these tasks through Ctrl + C won't abort the update.

There are three cronjobs running in the background to keep data up to date. They are rake tasks and can be manually run by executing
- `rake redshift:auditlog:import`: Retrieves newest queries from the Redshift audit logs.
- `rake redshift:tablereports:update`: Updates all the table statistics.
- `rake redshift:permissions:update`: Updates permissions cached locally.
The cron jobs are configured using 'whenever' in 'config/schedule.rb' and updated automatically on deployment. To enable them locally run 'whenever --update-crontab'.

Export Execution
---------------------
Exports are executed in long-running background processes. To start this background process locally run `./scripts/que run`. On a server capistrano will run `./scripts/que start|restart|stop` to manage these background processes.

Running
---------------------
`shotgun` for the webserver. `desmond run` for the background processes.

To get a console
---------------------
`tux`

Running tests
---------------------
First make sure you configured 'config/tests.yml', then run `rspec`

To deploy
---------------------
`cap staging deploy`

View at
---------------------
http://localhost:9393/
