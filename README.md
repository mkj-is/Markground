# Markground

Convert Playground files to Markdown documentation! Ever wanted to export
your documentation or blog post from Swift Playgrounds? Now you have chance.
The script can export playgrounds with or without pages.

You basically just need to type this in the Terminal:

```
./markground.swift MyPlayground.playground
```

## Arguments

* `--help` or `-h` — Open the help.
* `--no-toc` or `-t` — Disable the Table of Contents generation (it is generated only for playground with pages).
* `-o <path>` — Path to the output file, it will be rewritten. If not set then the result will be printed to the Terminal or stdout.

This is the example with all arguments:

```
./markground.swift --no-toc -o README.md MyPlayground.playground
```
