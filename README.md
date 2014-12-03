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
```

### Configuration
1. Configure PostgreSQL and Redhsift database connections in config/database.yml
  - run `rake db:setup`
2. Configure OAuth authentication in config/auth.yml
  - Google
    - provider: google_oauth2
    - Retrieve Client ID credentials from https://console.developers.google.com
      - Redirect URIs: <host>/auth/google_oauth2/callback
      - Javascript Origins: <host>
3. Configure AWS credentials in config/aws.yml
4. Configure the cache in config/cache.yml
  - ActiveRecord
    - Uses the configured primary ActiveRecord database connection as a cache
    - type: activerecord
    - table: <full model class name>
  - DynamoDB
    - uses AWS DynamoDB as a cache
    - type: dynamodb
    - table: <table name>


Running
---------------------
`shotgun`

To get a console
---------------------
`tux`

To deploy
---------------------
`cap staging deploy`
(or `cap production deploy`, which for the time being actually goes to the same place)

View at
---------------------
http://localhost:9393/
