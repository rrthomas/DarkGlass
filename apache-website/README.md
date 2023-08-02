# Apache template

This directory contains a template for a DarkGlass site on Apache.

## Configuration

Add the following files:

* `Hostname`: hostname of the web site (assuming the site is at the root of the host).
* `DocumentRoot`: path to files for the web site
* `AdminEmail`: email of site administrator

Then run:

```
nancy website.nancy.conf website.conf
sudo cp website.conf /etc/apache2/sites-available/NAME.conf
sudo a2ensite website
```
