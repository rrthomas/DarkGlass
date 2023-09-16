## Static sites

To use DarkGlass to generate a web site, run the following command from the DarkGlass git directory:

```
./scripts/static-site /PATH/TO/web.pl /PATH/TO/OUTPUT
```

Here, `web.pl` is the configuration script for DarkGlass, and the `OUTPUT`
path is where the files for your web server go.

You can add the `--verbose` flag to the command to show its progress; for more information, run: `./scripts/static-site --help`.
