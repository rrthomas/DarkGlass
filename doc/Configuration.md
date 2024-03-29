# Configuration

DarkGlass is configured in the `web.pl` script. The configuration variables are as follows:

=`ServerUrl`=
    The URL of the server.
=`BaseUrl`=
    The base URL of the site relative to the web server. It will typically contain a leading slash. It is used to construct relative URLs to make links within the site. An absolute URL (excluding the initial `http:`) can be used if desired.
=`DocumentRoot`=
    The file path to the top-level directory of the site content.
=`Author`=
    The name of the web site's owner.
=`Email`=
    The email address of the web site's owner.

If you want more than one web site, make a copy of `web.pl` under a different name for each site and configure each copy appropriately.