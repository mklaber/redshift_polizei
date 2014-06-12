<img src="https://s3.amazonaws.com/amg-public/github/polizei.png" align="right" alt="Redshift Polizei ('Police')" />
Redshift Polizei ("Police")
================

Sinatra app for monitoring a Redshift cluster. Built using [Twitter Bootstrap](http://getbootstrap.com/), [Font Awesome](http://fortawesome.github.io/Font-Awesome/) and duck tape.

Setup
---------------------
`bundle install`
<<<<<<< HEAD
`cp config/database.sample.yml config/database.yml`
(and edit with your credentials)
=======
'go to config folder.  copy database.sample.yaml into a file called database.yml'
'edit login credentials in database.yml to get database access'
>>>>>>> 8a263c291869dc651c2cacb31115c91ae3b1bb59

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
