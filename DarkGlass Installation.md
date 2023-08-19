# DarkGlass Installation

To install DarkGlass you’ll need Perl, Python, Git and ImageMagick
installed.

You will also need the following Perl packages: CGI.pm, File::Slurp, File::MimeInfo, Image::ExifTool, DateTime, HTML::Tiny, XML::LibXSLT, XML::Atom, PDF::API2.

Then run the following commands:

```
git clone https://github.com/rrthomas/DarkGlass
cd DarkGlass
./install.sh /PATH/TO/YOUR/DOCUMENT-ROOT /PATH/TO/YOUR/CGI-BIN
```

(You can use the same `install.sh` command to update a DarkGlass installation with a newer version.)

Then, configure the `web.pl` script as described in [DarkGlass Configuration](DarkGlass Configuration.md).

The input files correspond directly to output files. Web pages are written
as Markdown files, whose contents is then templated into the structure given
by the `view.html` template file, which you can customize as desired. Other
resources such as media files, CSS (including DarkGlass’s own `style.css`)
and any web server configuration files, are rendered verbatim.

Depending on whether you want to use DarkGlass statically or dynamically, see the [DarkGlass Static Sites](DarkGlass Static Sites.md) or [DarkGlass Dynamic Sites](DarkGlass Dynamic Sites.md).

The site should now be ready to use.

Then, see [DarkGlass Customization](DarkGlass Customization.md) for details of the various ways in which DarkGlass can be customized.
