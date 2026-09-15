// =====================================================
// SPACE CANVAS - 3D coordinate system
// =====================================================

#import "@preview/cetz:0.4.2"
#import "draw.typ": draw-geo, get-line-style, format-label

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

    // Everything the camera has to sort: the scaffolding and, below, every
    // facet of every surface.  Drawn in two passes -- axes first, objects
    // after -- an axis went under whatever was drawn later however far
    // behind it that was, so the far side of a cone painted over the z-axis
    // standing in front of it.
    //
    // A long line has no single depth, so each one is cut into pieces and
    // each piece sorted on its own.  That is what lets an axis pass behind
    // an object and come out in front of it further along.
    let pieces(a, b, n, style, mark: none) = {
      let lerp(t) = (
        a.at(0) + (b.at(0) - a.at(0)) * t,
        a.at(1) + (b.at(1) - a.at(1)) * t,
        a.at(2) + (b.at(2) - a.at(2)) * t,
      )
      let out = ()
      for i in range(n) {
        let p0 = lerp(i / n)
        let p1 = lerp((i + 1) / n)
        let mid = ((p0.at(0) + p1.at(0)) / 2,
                   (p0.at(1) + p1.at(1)) / 2,
                   (p0.at(2) + p1.at(2)) / 2)
        // The arrow belongs to the far end, so only the last piece carries it.
        let el = if mark != none and i == n - 1 {
          line(at(p0), at(p1), stroke: style, mark: mark)
        } else {
          line(at(p0), at(p1), stroke: style)
        }
        out.push((depth: _dot(mid, cam.fwd), el: el))
      }
      out
    }

    let deep = ()

    // Grid
    if show-grid {
      for i in range(int(x-min / step), int(x-max / step) + 1) {
        let x = i * step
        deep += pieces((x, y-min, 0), (x, y-max, 0), 12, grid-style)
      }
      for i in range(int(y-min / step), int(y-max / step) + 1) {
        let y = i * step
        deep += pieces((x-min, y, 0), (x-max, y, 0), 12, grid-style)
      }
    }

    // Axes
    let axis-labels = ()
    if show-axes {
      let arrow = (end: "stealth", fill: axis-col)
      deep += pieces((0, 0, 0), (0, 0, z-max + 1), 16, axis-style, mark: arrow)
      deep += pieces((0, 0, 0), (x-max + 1, 0, 0), 16, axis-style, mark: arrow)
      deep += pieces((0, 0, 0), (0, y-max + 1, 0), 16, axis-style, mark: arrow)
      axis-labels = (
        (at((0, 0, z-max + 1.2)), z-label),
        (at((x-max + 1.2, 0, 0)), x-label),
        (at((0, y-max + 1.2, 0)), y-label),
      )

      // Tick marks
      if show-ticks {
        let tick-len = 0.2
        for i in range(int(x-min / step), int(x-max / step) + 1) {
          if i != 0 {
            let x = i * step
            deep += pieces((x, 0, -tick-len), (x, 0, tick-len), 1, tick-style)
          }
        }
        for i in range(int(y-min / step), int(y-max / step) + 1) {
          if i != 0 {
            let y = i * step
            deep += pieces((0, y, -tick-len), (0, y, tick-len), 1, tick-style)
          }
        }
        for i in range(int(z-min / step), int(z-max / step) + 1) {
          if i != 0 {
            let z = i * step
            deep += pieces((-tick-len, 0, z), (tick-len, 0, z), 1, tick-style)
          }
        }
      }
    }

    let bounds = (x: x-domain, y: y-domain, z: z-domain)
    let point-col = theme.at("plot", default: (:)).at("highlight", default: black)
    let vec-col = theme.at("plot", default: (:)).at("stroke", default: black)

    // Every facet of a surface, each tagged with its depth, for the one
    // back-to-front pass below.
    let surface-entries(obj) = {
        let (u0, u1) = obj.u-domain
        let (v0, v1) = obj.v-domain
        let base-col = if obj.color == auto { vec-col } else { obj.color }
        let lt = obj.light
        let ltn = calc.sqrt(_dot(lt, lt))
        let lt = if ltn > 0 { lt.map(c => c / ltn) } else { (0, 0, 1) }

        // Every facet with its centroid depth.  These go into the same
        // list as the axes and grid, so the whole picture is painted back
        // to front in one pass -- without that the last thing drawn wins
        // regardless of where it is.
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
        let out = ()
        for facet in facets {
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
          out.push((depth: facet.depth,
                    el: line(..facet.corners.map(at), close: true,
                             fill: fill-col, stroke: edge)))
        }
        out
    }

    // Draw user objects

    // A 3D object has to be drawn through the same camera as the axes, so
    // these are rendered here rather than handed to `draw-geo', which emits
    // raw coordinates for cetz's own transform and would land somewhere else
    // entirely the moment the projection stopped being flat.
    let draw-3d(obj) = {
      let kind = obj.at("type", default: none)
      if kind == "point" {
        // A point with no z sits on the ground plane, like every other flat
        // shape here; it used to go to `draw-geo' and land in the canvas
        // plane instead, which put it nowhere in particular.
        let col = if (obj.at("style", default: auto) != auto
                      and type(obj.at("style", default: none)) == dictionary
                      and "fill" in obj.style) {
          obj.style.fill
        } else { point-col }
        let zc = { let v = obj.at("z", default: 0); if v == none { 0 } else { v } }
        content(at((obj.x, obj.y, zc)),
                box(fill: col, radius: 50%, width: 5pt, height: 5pt))
        if obj.at("label", default: none) != none {
          content(at((obj.x, obj.y, zc)),
                  text(fill: col, size: 0.8em, [ #obj.label]), anchor: "west")
        }
      } else if kind in ("segment", "circle", "arc", "polygon", "text") {
        // A flat shape, laid on the ground plane and put through the camera.
        // Handing these to `draw-geo' instead drew them in the canvas plane,
        // ignoring the camera: a circle came out a circle on screen rather
        // than an ellipse lying on the floor, and a segment pointed wherever
        // the screen said rather than where the world did.
        // Only `style' is read, and not every flat kind has one -- `text-at'
        // carries `color' instead -- so ask with a dictionary that always does.
        let style = get-line-style((style: obj.at("style", default: auto)), theme)
        let fill-col = obj.at("fill", default: none)
        // Every point carries its own height.  `point' stores `z: none'
        // rather than omitting the key, so a default never fires: a shape
        // given plain (x, y) pairs sits on the ground plane, and one given
        // (x, y, z) triples sits wherever it was put.
        let zof(p) = { let v = p.at("z", default: 0); if v == none { 0 } else { v } }
        let flat(x, y, z) = at((x, y, z))
        if kind == "segment" {
          line(flat(obj.p1.x, obj.p1.y, zof(obj.p1)),
               flat(obj.p2.x, obj.p2.y, zof(obj.p2)), stroke: style.stroke)
          if obj.at("label", default: none) != none {
            content(flat((obj.p1.x + obj.p2.x) / 2, (obj.p1.y + obj.p2.y) / 2,
                         (zof(obj.p1) + zof(obj.p2)) / 2),
                    text(fill: style.stroke.at("paint", default: black),
                         format-label(obj, obj.label)),
                    anchor: "south", padding: 0.1)
          }
        } else if kind == "circle" or kind == "arc" {
          // Sampled rather than drawn as an arc: the camera turns a circle
          // into an ellipse, and an ellipse at an angle is not something
          // cetz's `arc' can be asked for.
          let steps = 64
          let (a0, a1) = if kind == "arc" { (obj.start, obj.end) } else { (0deg, 360deg) }
          let a1 = if kind == "arc" and a1 < a0 { a1 + 360deg } else { a1 }
          let pts = range(steps + 1).map(i => {
            let a = a0 + (a1 - a0) * i / steps
            flat(obj.center.x + obj.radius * calc.cos(a),
                 obj.center.y + obj.radius * calc.sin(a),
                 zof(obj.center))
          })
          if kind == "circle" {
            line(..pts, close: true, stroke: style.stroke, fill: fill-col)
          } else {
            line(..pts, stroke: style.stroke)
          }
        } else if kind == "polygon" {
          line(..obj.points.map(pt => flat(pt.x, pt.y, zof(pt))), close: true,
               stroke: style.stroke, fill: fill-col)
        } else if kind == "text" {
          let col = if obj.color == auto {
            theme.at("plot", default: (:)).at("stroke", default: black)
          } else { obj.color }
          content(flat(obj.x, obj.y, zof(obj)), text(fill: col, obj.body),
                  anchor: obj.anchor, angle: obj.angle, padding: obj.padding,
                  fill: obj.fill, frame: obj.frame, stroke: none)
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

    // Surfaces join the scaffolding, and the whole picture is painted in one
    // pass from the back forwards.  Sorting the facets only among themselves
    // is what let a far-side facet cover an axis in front of it.
    let flat = ()
    for obj in objects.pos() {
      if type(obj) == array { for sub in obj { flat.push(sub) } } else { flat.push(obj) }
    }
    for obj in flat {
      if (type(obj) == dictionary and obj.at("type", default: none) == "surface-3d"
          and not legacy-view) {
        deep += surface-entries(obj)
      }
    }
    for entry in deep.sorted(key: e => e.depth) { entry.el }

    // Labels sit outside the picture, past the end of each axis, so they are
    // never what an object should be hiding.
    for (pos, body) in axis-labels {
      content(pos, text(fill: axis-col, body))
    }

    for obj in flat {
      if type(obj) == dictionary and obj.at("type", default: none) != none {
        // Already painted above, in the sorted pass.
        if obj.type == "surface-3d" and not legacy-view { continue }
        // 3D only when it actually carries a z; a flat point still belongs to
        // `draw-geo', which knows every 2D style this module has.
        // Only the kinds `draw-3d' actually knows, and only when they carry a
        // z: a flat point still belongs to `draw-geo', which knows every 2D
        // style this module has.
        let kind = obj.at("type", default: "")
        let is3d = (not legacy-view
                    and kind in ("point", "vector", "vec-3d", "point-3d",
                                 "surface-3d", "brace-3d",
                                 "segment", "circle", "arc", "polygon", "text")
                    and (obj.at("z", default: none) != none
                         or kind in ("point", "vec-3d", "point-3d", "surface-3d",
                                     "brace-3d", "segment", "circle", "arc",
                                     "polygon", "text")))
        if is3d { draw-3d(obj) } else { draw-geo(obj, theme, bounds: bounds) }
      } else {
        // Anything that is not one of our geometry dictionaries is drawn as
        // it is.  `draw-vec-3d' and `draw-point-3d' return arrays of cetz
        // elements, so without this each element failed the dictionary test
        // and the whole thing was dropped -- silently, leaving a canvas with
        // axes and nothing in it.
        //
        // Wrapped in an array because a cetz element is a function and the
        // loop joins what each turn produces: a bare one cannot be joined
        // with the arrays the other branches return.
        (obj,)
      }
    }
  })
}

/// Draw a 3D vector (arrow) in space
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
