# DarkGlass ToDo

This list reflects the author’s priorities. If you’d like to help, or you have any other changes you’d like to see, please $email{contact me}.

   * Have human-readable names for MIME types in download links, and put them in sensible order (currently non-deterministic!)
   * Remove file suffixes, and have a sensible priority order for which file gets the URL when multiple files share a name.
   * Fix templating so Island isn’t a special case.
   * Tagging to generalize file hierarchy. Should work with a search engine. Start by tagging log entries.
   * Make DarkGlass feeds “deep”, i.e. all the way to the bottom of the tree from the current object, and tag-based (see tags).
   * Factor DarkGlass into a front-end to `cv` and a program that actually serves pages.
   * Have a scheme for commenting on any page via twitter or email (spam filtered). And by Atom publishing?
   * Make `nancy` as make rule.
   * Use UnionFS or similar to allow DarkGlass to write files to the directories from which it’s serving, so that we can cache conversions.
   * Add dependency-driven rendering, using some sort of make system that can be run manually, by CGI or by inotifyd.
   * `Convert.pm` should be a script again that is invoked by `make` (how do we know if a conversion is possible? Obvious way is to keep the module so we can interrogate the list of conversions, but also have a front end).
   * Add `{ogg,id3}info` to music tracks in DarkGlass.
   * Add date and other meta information to pictures.
   * Generalise meta-information? Return a hash for each file from which code can pick out information.
   * Look into publishing mail folders (hypermail, MHonArc, or by hand).
   * Add “recent changes” back using search.
   * Add site-based search back (search results dependent on authentication level?).
   * Allow any file to be overridden for presentation by a file called <file>.dg (consistent with directory scheme)?
   * Support the `link` element (should replace the navigation bar).
   * Use ideas from [Silk](https://hypertext.sourceforge.net/silk/userGuide.shtml), [LinkDatabase](http://www.usemod.com/cgi-bin/mb.pl?LinkDatabase), [TouchGraph](http://www.usemod.com/cgi-bin/mb.pl?TouchGraphWikiBrowser) and [Sylbi](https://sourceforge.net/projects/sylbi/).
   * Make more secure. In particular, ensure that URLs and file paths are always clean, preferably at the datatype level. Look for other potential security problems.
   * Allow editing and file management through the web interface? Or the other way around, plugging into other protocols?