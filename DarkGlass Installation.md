# DarkGlass Installation

In order to run DarkGlass, you need access to a web server capable of running [Perl](https://www.perl.org) CGI scripts (Perl 5.8.7 or later). If you’re not sure what some of that means, you’re probably not ready to install DarkGlass yourself, and you should seek help (e.g. do some web searches to learn about web servers and CGI scripts, or ask the person who runs your web server for help).

To install DarkGlass:

```
git clone https://github.com/rrthomas/DarkGlass
cd DarkGlass
./install.sh /PATH/TO/YOUR/DOCUMENT-ROOT /PATH/TO/YOUR/CGI-BIN
```

(You can use the same `install.sh` command to update a DarkGlass installation with a newer version.)

Then, configure the `web.pl` script as described in [DarkGlass Configuration](DarkGlass Configuration.md).

The wiki should now be ready to use. See [DarkGlass Customization](DarkGlass Customization.md) for details of the various ways in which DarkGlass can be customized.

See [DarkGlass Organization](DarkGlass Organization.md) for more details of the layout of the files and URLs used by DarkGlass.