# Macros

Macros are special markup which add functionality to Linton. A macro call is written `\$macro` if the macro takes no arguments, or `\$macro{arg_1_,…,arg_n_}` if it does. Commas in macro arguments must be escaped with backslashes. Unwanted arguments may be omitted.

Macros are evaluated after Markdown is converted to HTML.

FIXME: Documentation of some macros is missing. The documentation should really be extracted from the code.

=`\$page`=
    The site-relative path of the current page.
=`\$pagename`=
    The name of the current page (the last path component of `\$page`).
=`\$lastmodified`=
    The date on which the current page was last modified.
=`\$include{_file_}`=
    Inserts the contents of the given file, or nothing if the file cannot be read.
=`\$email{_text_}`=
    Makes `_text_` a link to send mail to the administrator (see [Configuration](Configuration.html)).