## Static sites

To use DarkGlass to generate a web site, run the following command from the DarkGlass git directory:

```
./scripts/static-site /PATH/TO/web.pl /PATH/TO/OUTPUT
```

Here, `web.pl` is the configuration script for DarkGlass, and the `OUTPUT`
path is where the files for your web server go.

You can add the `--verbose` flag to the command to show its progress; for more information, run: `./scripts/static-site --help`.

### Serving static files correctly

When a static site is built, files are often converted from one type to another, but keep the same name. For example, a Markdown file `foo.md` is normally converted to an HTML file `foo.md`. The name is not changed, as that would break links, which DarkGlass has no easy way to rewrite.

This can confuse your web server, as web servers often treat a file
according to its file extension. For Apache, the following directive in an
`.htaccess` file will cause Markdown files to be served as HTML:

```
AddType text/html md
```
