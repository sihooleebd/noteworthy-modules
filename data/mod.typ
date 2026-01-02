// =====================================================
// DATA MODULE - Main entrypoint for data handling
// =====================================================
// Re-exports all data types with theme binding where needed.

#import "../../core/setup.typ": active-theme

// Data series (no theme needed)
#import "series.typ": *

// Curve interpolation (no theme needed)
#import "curve.typ": *

// Table objects and raw renderers
#import "table.typ": grid-data, render-grid, render-table, table-data, value-table-data

// =====================================================
// THEMED TABLE WRAPPERS
// =====================================================

#let table-plot(headers: (), data: (), horizontal: false, ..args) = {
  let obj = table-data(headers, data, horizontal: horizontal, style: args.named())
  render-table(obj, active-theme)
}

#let compact-table(headers: (), data: (), horizontal: false, ..args) = {
  let obj = table-data(headers, data, horizontal: horizontal, style: args.named())
  render-table(obj, active-theme)
}

#let value-table(variable: $x$, func: $f(x)$, values: (), results: (), horizontal: false, ..args) = {
  let obj = value-table-data(variable, func, values, results, horizontal: horizontal, style: args.named())
  render-table(obj, active-theme)
}

#let grid-table(data: (), show-indices: false, horizontal: false, ..args) = {
  let obj = grid-data(data, show-indices: show-indices, horizontal: horizontal, style: args.named())
  render-grid(obj, active-theme)
}
