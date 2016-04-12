<img src="https://s3.amazonaws.com/amg-public/github/polizei.png" align="right" alt="Redshift Polizei ('Police')" />
Redshift Polizei ("Police")
================

Sinatra app for monitoring a Redshift cluster. Built using [Twitter Bootstrap](http://getbootstrap.com/), [Font Awesome](http://fortawesome.github.io/Font-Awesome/) and duck tape.

[![Coverage Status](https://coveralls.io/repos/AnalyticsMediaGroup/redshift_polizei/badge.svg?branch=origin%2Fmaster&service=github)](https://coveralls.io/github/AnalyticsMediaGroup/redshift_polizei?branch=origin%2Fmaster)

Setup
---------------------
```
bundle install
cp config/database.sample.yml config/database.yml
cp config/polizei.sample.yml config/polizei.yml
```
Make sure to enable `pg_trgm` extension in the PostgreSQL database: `CREATE EXTENSION pg_trgm;`

Configuration
---------------------
All configuration files can be found in the `config/` directory.

1. Configure PostgreSQL and RedShift database connections in `config/database.yml`
	- run `rake db:setup`
2. Configure OAuth authentication in `config/polizei.yml`
    - For Google Outh 2.0:
        - `auth_provider: GoogleOauth2`
        - Create/retrieve `auth_client_id` and `auth_client_secret` from https://console.developers.google.com
        - Redirect URIs: {host}/auth/google_oauth2/callback
            - Ex: http://localhost:9393/auth/google_oauth2/callback
        - Javascript Origins: {host}
            - Ex: http://localhost:9393
3. Configure AWS credentials in `config/polizei.yml`
4. Set the mail settings in `config/polizei.yml`
    - All settings will be directly injected into Pony.options
	- You may need an application-specific password if using Google
5. Set the general application settings in `config/polizei.yml`

Reports
---------------------
1. Running Queries
Displays currently executing queries on your RedShift cluster and completed queries missing from the audit log. Always retrieved uncached from RedShift system tables.
2. Audit Log
Shows queries which were run on the cluster in the past (by default max 30 days). Retrieved from Postgres database. The redshift audit logs are parsed regularly by a cron job to fill the pg database. The audit log importer can be manually trigger by running `rake redshift:auditlog:import` (see [Data Acquisition](#data-acquisition) below).
3. Tables
Displays size, keys, skew and more for all user tables. Read from system tables, then saved in Postgres from where the information is retrieved to display it. Automatically updated via cronjob. Manually updateable with `rake redshift:tablereports:update` (see [Data Acquisition](#data-acquisition) below) or through the Update button in the web frontend.
4. Permissions
Displays permissions users or groups have on tables. Retrieved from pg database. Automatically updated in the background, manual trigger using `rake redshift:permissions:update`.
5. Disk Space
Retrieved uncached from CloudWatch using the `PercentageDiskSpaceUsed` metric.
6. Exports
Job details are saved and queued in the pg database. Background processes retrieve queued jobs and execute their queries on the cluster, saving the results to S3 (use `desmond run` to run background daemon).

Data Acquisition
---------------------
All cached and generated data can be updated using `rake reports:update`. This takes quite a long time if there are a lot of audit logs to be parsed. This command can be used to update cached data before it is regularly updated or to precache on new deployments.

There are three cronjobs running in the background to keep data up to date. They are rake tasks and can be manually run by executing

- `rake redshift:auditlog:import`: Retrieves newest queries from the Redshift audit logs.
- `rake redshift:tablereports:update`: Updates all the table statistics.
- `rake redshift:permissions:update`: Updates permissions cached locally.

The cron jobs are configured using 'whenever' in `config/schedule.rb` and updated automatically on deployment. To enable them locally run 'whenever --update-crontab'.

Running
---------------------
`shotgun` for the webserver. `desmond run` for the background processes.
<br>You may need to build and install the [desmond](https://github.com/AnalyticsMediaGroup/desmond) gem.
<br>If you get SSL issues try running `rvm osx-ssl-certs update all`

To get a console
---------------------
`tux`

Running tests
---------------------
1. Configure the `test` environment in `polizei.yml`
2. Configure the `test` and `redshift_test` environments in `database.yml`
3. Run `rspec`

To deploy
---------------------
Make sure the deploy configuration options are set in `config/polizei.yml` (`deploy_server_url` and `deploy_server_path`), then run `cap production deploy`

View at
---------------------
http://localhost:9999/

To deploy via Dockerfile
---------------------
You will need to create the `polizei.yml` and `database.yml` config files prior to running the container.

```
git clone https://github.com/AnalyticsMediaGroup/redshift_polizei
cd redshift_polizei
docker build -t AnalyticsMediaGroup/redshift_polizei .
docker run -d -v $PWD/config/polizei.yml:/apps/polizei/config/polizei.yml -v $PWD/config/database.yml:/apps/polizei/config/database.yml -p 9999:9999 -name redshift_polizei AnalyticsMediaGroup/redshift_polizei
```
