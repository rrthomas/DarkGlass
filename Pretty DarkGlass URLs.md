# Pretty DarkGlass URLs

You need to set up your web server so that using the URL of the web site plus the name of the page causes the page to be shown, i.e. URLs of the form `BaseUrl`/_Foo_ are mapped to the incantation required to view web page _Foo_. This makes URLs pointing into the web site much more readable (and easy to copy and type).

Please $email{send me} instructions for other web servers if you can.

## Apache

Put the following in the `.htaccess` file of the directory specified by `DocumentRoot` in the wiki configuration, filling in the value of `ScriptUrl` where indicated. For rewrites to work the directory in question has to be in the scope of an `AllowOverride FileInfo` directive. See the [Apache documentation](https://httpd.apache.org/docs/) for the gory details.

    # Use DarkGlass for all URLs
    RewriteEngine on
    RewriteRule ^(.*)$ <ScriptUrl>

In the `cgi-bin` directory, add the following `.htaccess` file:

    RewriteEngine off
    Options +ExecCGI
    SetHandler cgi-script
