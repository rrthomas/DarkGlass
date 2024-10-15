# How output is generated from input

Consider the following input directory tree:

- `README.html`
- `Foo.html`
- `Bar.txt`
- `baz.pdf`
- `favicon.ico`
- `image.jpg`
- `style.css` (by default, the supplied CSS file)

For each file, Linton first decides whether to convert it to HTML. By default, it knows how to convert plain text, Markdown and LaTeX files, so given the files above, it will convert `Foo.html` and `README.html` to web pages. Other files are published as-is.

Files that are converted to web pages go through the following procedure:

* Convert the file to HTML
* Macro-expand the `view.html` template (see [macros](Macros.html) and [Templates](Templates.html)), using the `<body>` element of the result as the value of the `\$text` macro.

Note that `README.html` is a special case: it is converted to `index.html`.

So, for the example files above, the following will be generated as output:

- `index.html` (generated from `README.html`)
- `Foo.html`
- `Bar.html`
- `baz.pdf`
- `favicon.ico`
- `image.jpg`
- `style.css`
