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
  - All settings will be directly injected into ActionMailer 'smtp_settings' (see http://guides.rubyonrails.org/action_mailer_basics.html#action-mailer-configuration)

Data Acquisition
---------------------
The Audit Log relies on RedShift Audit Logs stored on S3, which is why `Reports::AuditLog.update_from_s3` has to be run regularly.

All Reports can be kept in cache be running `app/renew_reports.rb` regularly. Otherwise the cache will be updated once the reports data is expired and accessed.

There are two cronjobs running in the background to keep data up to date. They are rake tasks and can be manually run by executing
- `rake redshift:auditlog:import`: Retrieves newest queries from the Redshift audit logs.
- `rake redshift:tablereport:update`: Updates all the table statistics
The cron jobs are configured using 'whenever' in 'config/schedule.rb' and updated automatically on deployment. To enable them locally run 'whenever --update-crontab'.

Running
---------------------
`shotgun`

To get a console
---------------------
`tux`

To deploy
---------------------
`cap staging deploy`

View at
---------------------
http://localhost:9393/
