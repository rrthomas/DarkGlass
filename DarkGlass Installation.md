# DarkGlass Installation

To install DarkGlass you’ll need Perl, Python and Git installed. Then run the following commands:

```
git clone https://github.com/rrthomas/DarkGlass
cd DarkGlass
./install.sh /PATH/TO/YOUR/DOCUMENT-ROOT /PATH/TO/YOUR/CGI-BIN
```

(You can use the same `install.sh` command to update a DarkGlass installation with a newer version.)

Then, configure the `web.pl` script as described in [DarkGlass Configuration](DarkGlass Configuration.md).

Depending on whether you want to use DarkGlass statically or dynamically, see the relevant section below.

The site should now be ready to use.

Then, see:

* [DarkGlass Customization](DarkGlass Customization.md) for details of the various ways in which DarkGlass can be customized.
* [DarkGlass Organization](DarkGlass Organization.md) for more details of the layout of the files and URLs used by DarkGlass.

## Dynamic DarkGlass

In order to run DarkGlass dynamically, you need access to a web server capable of running [Perl](https://www.perl.org) CGI scripts. If you’re not sure what some of that means, you’re probably not ready to install DarkGlass yourself, and you should seek help (e.g. do some web searches to learn about web servers and CGI scripts, or ask the person who runs your web server for help).

## Static DarkGlass

To use DarkGlass to generate a web site, run the following command from the DarkGlass git directory:

```
./scripts/static-site /PATH/TO/web.pl /PATH/TO/YOUR/DOCUMENT-ROOT
```

You can add the `--verbose` flag to the command to show its progress; for more information, run: `./scripts/static-site --help`.
