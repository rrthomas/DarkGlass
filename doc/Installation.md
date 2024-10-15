# Installation

To install Linton you’ll need Perl, Python and Git.

You will also need the following Perl package: File::Slurp.

Then run the following commands:

```
git clone https://github.com/rrthomas/Linton
cd Linton
./install.sh /PATH/TO/YOUR/DOCUMENT-ROOT /PATH/TO/YOUR/BIN
```

(You can use the same `install.sh` command to update a Linton
installation with a newer version; beware though that this overwrites files
you may have edited, such as `web.pl`, so you should take a copy before you
upgrade.)

Then, configure the `web.pl` script as described in
[Configuration](Configuration.html).

The input files correspond directly to output files. Web pages are written
as Markdown files, whose contents is then templated into the structure given
by the `view.html` template file, which you can customize as desired. Other
resources such as media files, CSS (including Linton’s own `style.css`)
and any web server configuration files, are rendered verbatim. See
[How output is generated from input](<How output is generated from input.html>)
for more details.

See [Publishing a site](Publishing a site.html).

The site should now be ready to use. See [Testing](Testing.html) for how to
test it in dynamic mode without configuring a web server.

Then, see [Customization](Customization.html) for details of the various
ways in which Linton can be customized.
