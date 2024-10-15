# How output is generated from input

Consider the following input directory tree:

- `README.md`
- `Foo.md`
- `Bar.txt`
- `baz.pdf`
- `favicon.ico`
- `image.jpg`
- `style.css` (by default, the supplied CSS file)

For each file, DarkGlass first decides whether to convert it to HTML. By default, it knows how to convert plain text, Markdown and LaTeX files, so given the files above, it will convert `Foo.md` and `README.md` to web pages. Other files are published as-is.

Files that are converted to web pages go through the following procedure:

* Convert the file to HTML
* Macro-expand the `view.html` template (see [macros](Macros.md) and [Templates](Templates.md)), using the `<body>` element of the result as the value of the `\$text` macro.

Note that `README.md` is a special case: it is converted to `index.html`.

So, for the example files above, the following will be generated as output:

- `index.html` (generated from `README.md`)
- `Foo.html`
- `Bar.html`
- `baz.pdf`
- `favicon.ico`
- `image.jpg`
- `style.css`
