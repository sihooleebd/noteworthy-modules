// =====================================================
// SPACE CANVAS - 3D coordinate system
// =====================================================

#import "@preview/cetz:0.4.2"
#import "draw.typ": draw-geo

// =====================================================
// Camera
// =====================================================
//
// The scene used to be turned with cetz's `rotate(x:, y:, z:)', which is
// three Euler angles about the fixed world axes composed as Rz.Ry.Rx -- so
// the knobs interact and none of them is "where the camera is".  Worse, cetz
// can only ever draw this flat: `mul4x4-vec3' discards the matrix's fourth
// row and there is no homogeneous divide anywhere in its pipeline, so a
// perspective term would be computed and then dropped.
//
// So the projection happens here instead.  `azimuth' turns the camera around
// the z-axis, `elevation' lifts it above the xy-plane, and both mean exactly
// that on their own.

#let _dot(a, b) = a.at(0) * b.at(0) + a.at(1) * b.at(1) + a.at(2) * b.at(2)

#let _camera(azimuth, elevation) = (
  right: (-calc.sin(azimuth), calc.cos(azimuth), 0.0),
  up: (
    -calc.sin(elevation) * calc.cos(azimuth),
    -calc.sin(elevation) * calc.sin(azimuth),
    calc.cos(elevation),
  ),
  // Towards the camera, so a larger dot product means nearer the eye.
  fwd: (
    calc.cos(elevation) * calc.cos(azimuth),
    calc.cos(elevation) * calc.sin(azimuth),
    calc.sin(elevation),
  ),
)

/// A 3D point as page coordinates.
///
/// Under `perspective' the scale is 1 at the origin and grows towards the
/// camera, so `distance' reads as "how far away the eye is, in scene units":
/// large is nearly flat, small exaggerates.
#let _project(p, cam, projection, distance) = {
  let v = if type(p) == array {
    (p.at(0, default: 0), p.at(1, default: 0), p.at(2, default: 0))
  } else if type(p) == dictionary {
    (p.at("x", default: 0), p.at("y", default: 0), p.at("z", default: 0))
  } else {
    (0, 0, 0)
  }
  let x = _dot(v, cam.right)
  let y = _dot(v, cam.up)
  if projection == "perspective" {
    let depth = distance - _dot(v, cam.fwd)
    // Behind the eye there is no honest answer; clamp rather than mirror the
    // point through the origin, which is what a bare divide would do.
    let scale = if depth > 0.01 { distance / depth } else { distance / 0.01 }
    (x * scale, y * scale)
  } else {
    (x, y)
  }
}

/// Create a 3D space canvas
/// Renders 3D geometry objects with perspective projection.
///
/// Parameters:
/// - theme: Theme dictionary for styling
/// - x-domain: X-axis range (default: (0, 5))
/// - y-domain: Y-axis range (default: (0, 5))
/// - z-domain: Z-axis range (default: (0, 4))
/// - azimuth: Camera angle around the z-axis (default: 30deg)
/// - elevation: Camera height above the xy-plane (default: 30deg)
/// - projection: "orthographic" or "perspective" (default: "orthographic")
/// - distance: Eye distance in scene units, perspective only (default: 12)
/// - view: Deprecated raw Euler angles (x:, y:, z:); see the camera note
/// - step: Grid line spacing (default: 1)
/// - x-label, y-label, z-label: Axis labels
/// - show-axes: Whether to show axes (default: true)
/// - show-grid: Whether to show XY grid (default: true)
/// - show-ticks: Whether to show tick marks (default: false)
/// - size: Drawing extent as (x, y) or (x, y, z) in canvas units, the way
///   `cartesian-canvas' takes it: each domain is mapped onto that many units,
///   so the picture's size stops depending on what the domains happen to be.
///   A two-entry size scales z with x, which keeps the vertical honest.
///   Default `none' -- one scene unit is one canvas unit.
/// - length: Size of one canvas unit (default: 1cm), for scaling the whole
///   drawing without changing its proportions.
/// - ..objects: Geometry objects to render
#let space-canvas(
  theme: (:),
  x-domain: (0, 5),
  y-domain: (0, 5),
  z-domain: (0, 4),
  azimuth: 30deg,
  elevation: 30deg,
  projection: "orthographic",
  distance: 12,
  view: none,
  step: 1,
  x-label: $x$,
  y-label: $y$,
  z-label: $z$,
  show-axes: true,
  show-grid: true,
  show-ticks: false,
  size: none,
  length: 1cm,
  ..objects,
) = {
  // Named arguments fall into `..objects', where only `.pos()' is ever read --
  // so a misspelled one, or one that never existed, did nothing at all and
  // said nothing.  This module's own documentation passed `width: 10cm' for
  // exactly that reason.  Refuse instead.
  if objects.named().len() > 0 {
    panic("space-canvas: unknown argument(s): "
          + objects.named().keys().join(", ")
          + ". Size is set with `length' (the size of one scene unit).")
  }
  let axis-col = theme.at("plot", default: (:)).at("stroke", default: black)
  let grid-col = theme.at("plot", default: (:)).at("grid", default: gray)

  let axis-style = (paint: axis-col, thickness: 1pt)
  let grid-style = (paint: grid-col, thickness: 0.5pt)
  let tick-style = (paint: axis-col, thickness: 1pt)

  // `view' predates the camera and is three Euler angles about the world
  // axes.  Honoured when given, so old documents keep their framing, but it
  // cannot be projected -- cetz throws the perspective term away -- so it
  // stays flat and is worth moving off.
  let legacy-view = view != none
  let cam = _camera(azimuth, elevation)
  let proj = if projection == "perspective" and not legacy-view {
    "perspective"
  } else {
    "orthographic"
  }
  // Every coordinate in here goes through this, and comes out as page
  // coordinates -- so what is drawn is what the camera sees, rather than
  // whatever cetz's affine stack could manage.
  // Map each domain onto the requested extent before projecting, so the
  // drawing is the size asked for rather than the size the numbers happen to
  // imply.  Done here, in front of the camera, so perspective depth is
  // measured in the same units as everything else.
  let span(d) = {
    let w = d.at(1) - d.at(0)
    if w == 0 { 1 } else { w }
  }
  let sx = if size == none { 1 } else { size.at(0) / span(x-domain) }
  let sy = if size == none { 1 } else { size.at(1) / span(y-domain) }
  let sz = if size == none { 1 } else if size.len() > 2 {
    size.at(2) / span(z-domain)
  } else { sx }
  let scaled = p => (
    p.at(0, default: 0) * sx,
    p.at(1, default: 0) * sy,
    p.at(2, default: 0) * sz,
  )
  let at = p => if legacy-view { p } else {
    _project(scaled(p), cam, proj, distance)
  }

  cetz.canvas(length: length, {
    import cetz.draw: *

    if legacy-view {
      rotate(x: view.at("x", default: 0deg), y: view.at("y", default: 0deg), z: view.at("z", default: 0deg))
    }

    let (x-min, x-max) = x-domain
    let (y-min, y-max) = y-domain
    let (z-min, z-max) = z-domain

    // Draw grid
    if show-grid {
      for i in range(int(x-min / step), int(x-max / step) + 1) {
        let x = i * step
        line(at((x, y-min, 0)), at((x, y-max, 0)), stroke: grid-style)
      }
      for i in range(int(y-min / step), int(y-max / step) + 1) {
        let y = i * step
        line(at((x-min, y, 0)), at((x-max, y, 0)), stroke: grid-style)
      }
    }

    // Draw axes
    if show-axes {
      // Z-Axis (vertical)
      line(at((0, 0, 0)), at((0, 0, z-max + 1)), stroke: axis-style, mark: (end: "stealth", fill: axis-col), name: "z-axis")
      content(at((0, 0, z-max + 1.2)), text(fill: axis-col, z-label))

      // X-Axis
      line(at((0, 0, 0)), at((x-max + 1, 0, 0)), stroke: axis-style, mark: (end: "stealth", fill: axis-col), name: "x-axis")
      content(at((x-max + 1.2, 0, 0)), text(fill: axis-col, x-label))

      // Y-Axis
      line(at((0, 0, 0)), at((0, y-max + 1, 0)), stroke: axis-style, mark: (end: "stealth", fill: axis-col), name: "y-axis")
      content(at((0, y-max + 1.2, 0)), text(fill: axis-col, y-label))

      // Tick marks
      if show-ticks {
        let tick-len = 0.2
        for i in range(int(x-min / step), int(x-max / step) + 1) {
          if i != 0 {
            let x = i * step
            line(at((x, 0, -tick-len)), at((x, 0, tick-len)), stroke: tick-style)
          }
        }
        for i in range(int(y-min / step), int(y-max / step) + 1) {
          if i != 0 {
            let y = i * step
            line(at((0, y, -tick-len)), at((0, y, tick-len)), stroke: tick-style)
          }
        }
        for i in range(int(z-min / step), int(z-max / step) + 1) {
          if i != 0 {
            let z = i * step
            line(at((-tick-len, 0, z)), at((tick-len, 0, z)), stroke: tick-style)
          }
        }
      }
    }

    // Draw user objects
    let bounds = (x: x-domain, y: y-domain, z: z-domain)
    let point-col = theme.at("plot", default: (:)).at("highlight", default: black)
    let vec-col = theme.at("plot", default: (:)).at("stroke", default: black)

    // A 3D object has to be drawn through the same camera as the axes, so
    // these are rendered here rather than handed to `draw-geo', which emits
    // raw coordinates for cetz's own transform and would land somewhere else
    // entirely the moment the projection stopped being flat.
    let draw-3d(obj) = {
      let kind = obj.at("type", default: none)
      if kind == "point" {
        let col = point-col
        content(at((obj.x, obj.y, obj.at("z", default: 0))),
                box(fill: col, radius: 50%, width: 5pt, height: 5pt))
        if obj.at("label", default: none) != none {
          content(at((obj.x, obj.y, obj.at("z", default: 0))),
                  text(fill: col, size: 0.8em, [ #obj.label]), anchor: "west")
        }
      } else if kind == "surface-3d" {
        let (u0, u1) = obj.u-domain
        let (v0, v1) = obj.v-domain
        let base-col = if obj.color == auto { vec-col } else { obj.color }
        let lt = obj.light
        let ltn = calc.sqrt(_dot(lt, lt))
        let lt = if ltn > 0 { lt.map(c => c / ltn) } else { (0, 0, 1) }

        // Build every facet with its centroid depth, then paint far ones
        // first.  Without the sort the last facet drawn wins regardless of
        // where it is, and the far side of the cone covers the near side.
        let facets = ()
        for i in range(obj.u-steps) {
          for j in range(obj.v-steps) {
            let u-a = u0 + (u1 - u0) * i / obj.u-steps
            let u-b = u0 + (u1 - u0) * (i + 1) / obj.u-steps
            let v-a = v0 + (v1 - v0) * j / obj.v-steps
            let v-b = v0 + (v1 - v0) * (j + 1) / obj.v-steps
            let corners = ((obj.f)(u-a, v-a), (obj.f)(u-b, v-a),
                           (obj.f)(u-b, v-b), (obj.f)(u-a, v-b))
            let c = (
              corners.map(p => p.at(0)).sum() / 4,
              corners.map(p => p.at(1)).sum() / 4,
              corners.map(p => p.at(2)).sum() / 4,
            )
            // Facet normal, for the shading only.
            let e1 = (corners.at(1).at(0) - corners.at(0).at(0),
                      corners.at(1).at(1) - corners.at(0).at(1),
                      corners.at(1).at(2) - corners.at(0).at(2))
            let e2 = (corners.at(3).at(0) - corners.at(0).at(0),
                      corners.at(3).at(1) - corners.at(0).at(1),
                      corners.at(3).at(2) - corners.at(0).at(2))
            let n = (e1.at(1) * e2.at(2) - e1.at(2) * e2.at(1),
                     e1.at(2) * e2.at(0) - e1.at(0) * e2.at(2),
                     e1.at(0) * e2.at(1) - e1.at(1) * e2.at(0))
            let nn = calc.sqrt(_dot(n, n))
            let n = if nn > 0 { n.map(c => c / nn) } else { (0, 0, 1) }
            facets.push((depth: _dot(c, cam.fwd), corners: corners, normal: n))
          }
        }
        for facet in facets.sorted(key: f => f.depth) {
          let fill-col = if obj.shade {
            let t = calc.max(0.15, calc.abs(_dot(facet.normal, lt)))
            // Not rounded to whole percent: at a fine mesh, neighbouring
            // facets would round to the same darkness and the gradient would
            // step instead of sweep.
            base-col.darken((1 - t) * 60%)
          } else {
            base-col
          }
          // Seams.  Two filled polygons that share an edge are antialiased
          // independently, so a hairline of background survives between them
          // and the mesh reads as moire even with no wireframe asked for.
          // Stroking each facet in its own fill closes the gap without
          // drawing anything you can see as a line.
          let edge = if obj.stroke == none {
            (paint: fill-col, thickness: 0.5pt)
          } else {
            obj.stroke
          }
          line(..facet.corners.map(at), close: true,
               fill: fill-col, stroke: edge)
        }
      } else if kind == "brace-3d" {
        let col = if obj.color == auto { vec-col } else { obj.color }
        let a = at(obj.from)
        let b = at(obj.to)
        cetz.decorations.brace(
          a, b,
          amplitude: obj.amplitude,
          flip: obj.flip,
          stroke: (paint: col, thickness: 1pt),
        )
        if obj.label != none {
          // Out along the brace's own normal, so the label sits clear of the
          // spike rather than on top of whatever the brace is measuring.
          let dx = b.at(0) - a.at(0)
          let dy = b.at(1) - a.at(1)
          let len = calc.sqrt(dx * dx + dy * dy)
          let (nx, ny) = if len > 0 { (-dy / len, dx / len) } else { (0, 1) }
          let sign = if obj.flip { -1 } else { 1 }
          let push = (obj.amplitude + obj.label-offset) * sign
          content(
            ((a.at(0) + b.at(0)) / 2 + nx * push,
             (a.at(1) + b.at(1)) / 2 + ny * push),
            text(fill: col, obj.label),
          )
        }
      } else if kind in ("vector", "vec-3d") {
        let from = obj.at("origin", default: (0, 0, 0))
        let to = if kind == "vec-3d" {
          obj.end
        } else {
          (obj.x, obj.y, obj.at("z", default: 0))
        }
        let from = if kind == "vec-3d" { obj.at("start", default: (0, 0, 0)) } else { from }
        let col = if obj.at("color", default: auto) == auto { vec-col } else { obj.color }
        line(at(from), at(to), stroke: (paint: col, thickness: 1.5pt),
             mark: (end: "stealth", fill: col))
        if obj.at("label", default: none) != none {
          content(at(to), text(fill: col, size: 0.8em, [ #obj.label]), anchor: "west")
        }
      }
    }

    for obj in objects.pos() {
      if type(obj) == dictionary and obj.at("type", default: none) != none {
        // 3D only when it actually carries a z; a flat point still belongs to
        // `draw-geo', which knows every 2D style this module has.
        // Only the kinds `draw-3d' actually knows, and only when they carry a
        // z: a flat point still belongs to `draw-geo', which knows every 2D
        // style this module has.
        let kind = obj.at("type", default: "")
        let is3d = (not legacy-view
                    and kind in ("point", "vector", "vec-3d", "point-3d",
                                 "surface-3d", "brace-3d")
                    and (obj.at("z", default: none) != none
                         or kind in ("vec-3d", "point-3d", "surface-3d", "brace-3d")))
        if is3d { draw-3d(obj) } else { draw-geo(obj, theme, bounds: bounds) }
      } else if type(obj) == array {
        // Handle arrays of objects (e.g., from vec-add, vec-components)
        for sub-obj in obj {
          if type(sub-obj) == dictionary and sub-obj.at("type", default: none) != none {
            draw-geo(sub-obj, theme, bounds: bounds)
          } else {
            // Anything that is not one of our geometry dictionaries is drawn
            // as it is.  `draw-vec-3d' and `draw-point-3d' return arrays of
            // cetz elements, so without this they fell into this branch, each
            // element failed the dictionary test, and the whole thing was
            // dropped -- silently, leaving a canvas with axes and nothing in
            // it.  That is every 3D vector and point this module can draw.
            //
            // Wrapped in an array because a cetz element is a function and
            // the loop joins what each turn produces: a bare one cannot be
            // joined with the arrays the other branches return.
            (sub-obj,)
          }
        }
      } else {
        obj
      }
    }
  })
}

/// Draw a 3D vector (arrow) in space
/// A parametric surface, drawn as filled facets.
///
/// CeTZ has no 3D renderer -- no depth buffer, no lighting, and cast shadows
/// are out of reach.  What it does have is filled polygons, and once the
/// camera is ours a surface is just facets sorted back to front and painted
/// in that order.  That is a painter's algorithm: correct for a convex shape
/// like a cone or a sphere, and wrong only where facets genuinely interleave.
///
/// `shade' darkens each facet by how far its normal turns from the light,
/// which is flat Lambert shading -- enough to read as a solid, with none of
/// the machinery real shading would need.
#let surface-3d(
  f,
  u-domain: (0, 360),
  v-domain: (0, 1),
  u-steps: 24,
  v-steps: 8,
  color: auto,
  shade: true,
  light: (0.4, -0.6, 0.7),
  stroke: none,
) = (
  type: "surface-3d",
  f: f,
  u-domain: u-domain,
  v-domain: v-domain,
  u-steps: u-steps,
  v-steps: v-steps,
  color: color,
  shade: shade,
  light: light,
  stroke: stroke,
)

/// A curly brace spanning two points in space, for measuring something.
///
/// The brace itself is flat -- it is an annotation drawn over the picture,
/// not an object in it -- so only its endpoints are projected.  That is what
/// you want: a dimension marker should keep its shape whatever the camera is
/// doing, the way one does on a drafting sheet.
#let brace-3d(
  from,
  to,
  label: none,
  amplitude: 0.4,
  flip: false,
  color: auto,
  label-offset: 0.35,
) = (
  type: "brace-3d",
  from: from,
  to: to,
  label: label,
  amplitude: amplitude,
  flip: flip,
  color: color,
  label-offset: label-offset,
)

#let draw-vec-3d(
  theme: (:),
  start: (0, 0, 0),
  end,
  label: none,
  color: auto,
) = {
  import cetz.draw: *

  let stroke-col = if color == auto {
    theme.at("plot", default: (:)).at("stroke", default: black)
  } else {
    color
  }

  line(
    start,
    end,
    stroke: (paint: stroke-col, thickness: 1.5pt),
    mark: (end: "stealth", fill: stroke-col),
  )

  if label != none {
    let bg-col = theme.at("page-fill", default: white)
    let mid = (
      (start.at(0) + end.at(0)) / 2,
      (start.at(1) + end.at(1)) / 2,
      (start.at(2) + end.at(2)) / 2,
    )

    // Use screen-space pill background for 3D
    content(
      mid,
      box(
        inset: (x: 4pt, y: 2pt),
        radius: 3pt,
        fill: bg-col,
        stroke: (paint: stroke-col, thickness: 0.5pt),
        text(fill: stroke-col, weight: "bold", label),
      ),
      anchor: "center",
    )
  }
}

/// Draw a 3D point with label
/// Uses a billboard-style marker that maintains consistent screen size
#let draw-point-3d(
  coords,
  theme: (:),
  label: none,
  color: auto,
  size: 5pt,
) = {
  import cetz.draw: *

  let fill-col = if color == auto {
    theme.at("plot", default: (:)).at("highlight", default: black)
  } else {
    color
  }

  // Extract coordinates
  let (px, py, pz) = if type(coords) == array {
    coords
  } else if type(coords) == dictionary {
    (coords.x, coords.y, coords.z)
  } else {
    (0, 0, 0)
  }

  // Use a filled square that renders at consistent screen size
  // Content in CeTZ is rendered in screen space, avoiding perspective distortion
  content(
    (px, py, pz),
    box(
      width: size,
      height: size,
      radius: size / 2, // Makes it circular
      fill: fill-col,
    ),
    anchor: "center",
  )

  if label != none {
    content(
      (px, py, pz),
      text(fill: theme.at("plot", default: (:)).at("stroke", default: black), label),
      anchor: "south-west",
      padding: 0.15,
    )
  }
}
