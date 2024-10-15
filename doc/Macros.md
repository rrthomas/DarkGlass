# Macros

Macros are special markup which add functionality to Linton. A macro call is written `\$macro` if the macro takes no arguments, or `\$macro{arg_1_,…,arg_n_}` if it does. Commas in macro arguments must be escaped with backslashes. Unwanted arguments may be omitted.

Macros are evaluated after Markdown is converted to HTML.

FIXME: Documentation of some macros is missing. The documentation should really be extracted from the code.

=`\$include{_file_}`=
    Inserts the contents of the given file, or nothing if the file cannot be read.