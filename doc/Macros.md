# Macros

Macros are special markup which add functionality to DarkGlass. A macro call is written `\$macro` if the macro takes no arguments, or `\$macro{arg_1_,…,arg_n_}` if it does. Commas in macro arguments must be escaped with backslashes. Unwanted arguments may be omitted.

Macros are evaluated after Markdown is converted to HTML.

FIXME: Documentation of some macros is missing. The documentation should really be extracted from the code.

=`\$page`=
    The site-relative path of the current page.
=`\$pagename`=
    The name of the current page (the last path component of `\$page`).
=`\$lastmodified`=
    The date on which the current page was last modified.
=`\$url{_path_}`=
    Make a URL from a site-relative path.
=`\$include{_file_}`=
    Inserts the contents of the given file from the templates directory, or nothing if the file cannot be read.
=`\$link{_url_,_description_,_class_}`=
    Produces a link to the given URL whose displayed text is `_description_` (set to the URL if not given). If the `_class_` argument is supplied, it is used to set the `class` attribute of the `a` element.
=`\$filesize{_file_}`=
    Inserts the size of the given file.
=`\$image{_image_,_alt_,_width_,_height_}`=
    Inserts the given image, which may be either a local file or a URL. If no width and height is given, and the image is a local image, the thumbnail is inserted instead, if any, and made a link to the image itself. The `_width_`, `_height_` and `_alt_` arguments are used for the corresponding HTML attributes.
=`\$imagecomment{_image_}`=
    Inserts the given image's EXIF comment, if any.
=`\$webfile{_file_,_format_}`=
    Produces a link to the given file in the download directory whose text is `_format_`, followed by the size of the file.
=`\$pdfpages{_file_}`=
    Inserts the number of pages in the given PDF file in the download directory.
=`\$email{_text_}`=
    Makes `_text_` a link to send mail to the administrator (see [Configuration](Configuration.md)).