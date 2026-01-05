# Noteworthy Modules

**Official Standard Library for the Noteworthy Framework.**

This repository contains the core collection of Typst modules used in the Noteworthy ecosystem. These modules provide specialized functionality for mathematics, computer science, plotting, and layout.

## Module List

| Module     | Description                                                          |
| :--------- | :------------------------------------------------------------------- |
| `canvas`   | Cartesian and polar coordinate systems for plotting.                 |
| `combi`    | Combinatorics utilities (grids, permutations).                       |
| `data`     | Data structures and visualization.                                   |
| `dsa`      | Data Structures & Algorithms visualizations (stacks, queues, trees). |
| `graph`    | Graph theory rendering tools.                                        |
| `layout`   | Layout primitives and page management.                               |
| `shape`    | Geometric shapes and drawing primitives.                             |
| `timeline` | Timeline and sequence visualizations.                                |
| `trees`    | Tree data structures and drawing.                                    |

## Usage

These modules are typically installed automatically as part of the Noteworthy framework setup. 

To use a module in your Noteworthy project:

```typst
#import "../../templates/templater.typ": *
```

Or individually:

```typst
#import "../../templates/module/dsa/mod.typ": *
```

## Contributing

We welcome additions to the standard library! Please read `CONTRIBUTING.md` for our module development philosophy and guidelines.

## License

MIT License. See `LICENSE` for details.
