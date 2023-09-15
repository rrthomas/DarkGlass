# How output is generated from input

Here is described how DarkGlass generates output files from input files when running dynamically. Static page generation is simpler, and the differences are described below.

Consider the following input directory tree:

- `README.md`
- `Foo.md`
- `Bar.txt`
- `baz.pdf`
- `favicon.ico`
- `image.jpg`
- `style.css` (by default, the supplied CSS file)

When asked for a given file, DarkGlass first decides whether to convert it to HTML. By default, it knows how to convert plain text, Markdown and LaTeX files, so given the files above, it will convert `Foo.md` and `README.md` to web pages. Other files are served as-is.

Files that are served as web pages go through the following procedure:

* Convert the file to HTML
* Macro-expand the `view.html` template (see [macros](Macros.md) and [Templates](Templates.md)), using the `<body>` element of the result as the value of the `\$text` macro.
* Serve the resulting page.

Note that `README.md` is a special case: it counts as an index page (like `index.html`), so it will be served when the directory containing it is requested.

As well as serving the default MIME type for a given file, other conversions may be available. For example, `image.jpg` may be requested in PNG format. This is handled by the `?convert` option to DarkGlass. The default `view.html` template displays available conversions for the user to download. This can also be used to get the source file for a web page. For example, requesting `Foo.md` will give a web page (type `text/html`), while the original Markdown can be retrieved by requesting `Foo.md?convert=text/markdown`.


## Static sites

For static sites, there are no alternate output formats available: each input file is either copied directly to the output, or converted to HTML. Also, index files are converted to a file called `index.html`, to be compatible with most web servers. So, for the example files above, the following will be generated as output:

- `index.html` (generated from `README.md`)
- `Foo.md` (N.B. this is an HTML file!)
- `Bar.txt` (N.B. this is an HTML file!)
- `baz.pdf`
- `favicon.ico`
- `image.jpg`
- `style.css`

To avoid needing to rewrite links, which DarkGlass is not currently able to do, output files other than index files have the same name as the input file. Most web servers will need to be told to serve files ending in `.md` as `text/html`; see [Static sites](Static sites.md).
