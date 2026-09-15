// =====================================================
// LINE, SEGMENT, RAY - Linear geometry objects
// =====================================================

#import "point.typ": is-point, point, as-point

/// Create a line segment between two points
/// A segment has definite endpoints and finite length.
///
/// Parameters:
/// - p1: First endpoint (point object or (x, y) tuple)
/// - p2: Second endpoint
/// - label: Optional label
/// - label-anchor: Optional anchor for label positioning
/// - style: Optional style overrides
/// - label-padding: Label padding value (default: 0.2)
#let segment(p1, p2, label: none, label-anchor: none, style: auto, label-padding: 0.2) = {
  // Convert tuples to points if needed
  let pt1 = as-point(p1)
  let pt2 = as-point(p2)

  (
    type: "segment",
    p1: pt1,
    p2: pt2,
    label: label,
    label-anchor: label-anchor,
    style: style,
    label-padding: label-padding,
  )
}

/// Create an infinite line through two points
/// A line extends infinitely in both directions.
///
/// Parameters:
/// - p1: First point on the line
/// - p2: Second point on the line
/// - label: Optional label
/// - label-anchor: Optional anchor for label positioning
/// - style: Optional style overrides
/// - label-padding: Label padding value (default: 0.2)
#let line(p1, p2, label: none, label-anchor: none, style: auto, label-padding: 0.2) = {
  let pt1 = as-point(p1)
  let pt2 = as-point(p2)

  (
    type: "line",
    p1: pt1,
    p2: pt2,
    label: label,
    label-anchor: label-anchor,
    style: style,
    label-padding: label-padding,
  )
}

/// Create a ray starting at origin, passing through a point
/// A ray extends infinitely in one direction from its origin.
///
/// Parameters:
/// - origin: Starting point of the ray
/// - through: A point the ray passes through
/// - label: Optional label
/// - label-anchor: Optional anchor for label positioning
/// - style: Optional style overrides
/// - label-padding: Label padding value (default: 0.2)
#let ray(origin, through, label: none, label-anchor: none, style: auto, label-padding: 0.2) = {
  let pt1 = as-point(origin)
  let pt2 = as-point(through)

  (
    type: "ray",
    origin: pt1,
    through: pt2,
    label: label,
    label-anchor: label-anchor,
    style: style,
    label-padding: label-padding,
  )
}

/// Create a line from a point in the direction of another point
///
/// Parameters:
/// - p: Point on the line
/// - direction: Point indicating the direction (line passes through p toward direction)
/// - style: Optional style overrides
/// - label-padding: Label padding value (default: 0.2)
#let line-through-direction(p, direction, style: auto, label-padding: 0.2) = {
  let pt = as-point(p)
  let dir = as-point(direction)
  line(pt, dir, style: style, label-padding: label-padding)
}

/// Create a line from a point and a slope
///
/// Parameters:
/// - p: Point on the line
/// - slope: Slope of the line
/// - style: Optional style overrides
#let line-point-slope(p, slope, ..args) = {
  let pt = as-point(p)
  let pt2 = point(pt.x + 1, pt.y + slope)
  
  line(pt, pt2, ..args)
}

/// Check if object is a segment
#let is-segment(obj) = {
  type(obj) == dictionary and obj.at("type", default: none) == "segment"
}

/// Check if object is a line
#let is-line(obj) = {
  type(obj) == dictionary and obj.at("type", default: none) == "line"
}

/// Check if object is a ray
#let is-ray(obj) = {
  type(obj) == dictionary and obj.at("type", default: none) == "ray"
}

/// Check if object is any linear type
#let is-linear(obj) = is-segment(obj) or is-line(obj) or is-ray(obj)

/// Get the direction vector of a linear object
#let linear-direction(obj) = {
  let p1 = if obj.type == "ray" { obj.origin } else { obj.p1 }
  let p2 = if obj.type == "ray" { obj.through } else { obj.p2 }
  (p2.x - p1.x, p2.y - p1.y)
}

/// Get the length of a segment
#let segment-length(seg) = {
  let dx = seg.p2.x - seg.p1.x
  let dy = seg.p2.y - seg.p1.y
  calc.sqrt(dx * dx + dy * dy)
}

// =====================================================
// Conversion Utilities
// =====================================================

/// Convert a ray to a segment of a given length
#let ray-to-segment(ray, length: 2) = {
  let o = ray.origin
  let t = ray.through
  let dir = (t.x - o.x, t.y - o.y)
  let norm = calc.sqrt(dir.at(0) * dir.at(0) + dir.at(1) * dir.at(1))
  if norm == 0 { return segment(o, o) }
  let udx = dir.at(0) / norm
  let udy = dir.at(1) / norm
  let p2 = point(o.x + length * udx, o.y + length * udy)
  segment(o, p2)
}

/// Convert a line to a segment of a given length, centered on its first point
#let line-to-segment(line, length: 2) = {
  let p1 = line.p1
  let p2 = line.p2
  let dir = (p2.x - p1.x, p2.y - p1.y)
  let norm = calc.sqrt(dir.at(0) * dir.at(0) + dir.at(1) * dir.at(1))
  if norm == 0 { return segment(p1, p1) }
  let udx = dir.at(0) / norm
  let udy = dir.at(1) / norm
  let half-len = length / 2.0
  let new-p1 = point(p1.x - half-len * udx, p1.y - half-len * udy)
  let new-p2 = point(p1.x + half-len * udx, p1.y + half-len * udy)
  segment(new-p1, new-p2)
}

/// Convert a segment to an infinite line
#let segment-to-line(seg) = {
  line(seg.p1, seg.p2)
}

/// Convert a segment to a ray
#let segment-to-ray(seg) = {
  ray(seg.p1, seg.p2)
}

/// Convert a ray to an infinite line
#let ray-to-line(r) = {
  line(r.origin, r.through)
}

/// Convert a line to a ray
#let line-to-ray(l) = {
  ray(l.p1, l.p2)
}

/// A curly brace spanning two points, for measuring something
///
/// The brace is an annotation drawn over the picture rather than an object
/// in it: `amplitude' is how far its spike stands off the span, and `angle'
/// says which way it leans out.  The label sits clear of the spike.
///
/// `angle' is a direction on the page -- 0deg right, 90deg up -- and the
/// brace goes to whichever of its two sides points that way.  A brace has
/// only those two sides, its span being fixed, so the angle chooses between
/// them rather than setting a bearing.  That is worth saying in a direction
/// rather than as a flag, because through a camera you cannot tell in
/// advance which side a flag lands on: `angle: 90deg' is above it on the
/// page whatever the projection does, while `flip' had to be discovered by
/// rendering.  Left unset, the brace sits to the left of `from' -> `to'.
///
/// Parameters:
/// - from: One end of the span
/// - to: The other end
/// - label: Optional label (e.g. $ell$)
/// - amplitude: Height of the brace (default: 0.4)
/// - angle: Which way it leans out, as a direction on the page (default: auto)
/// - flip: The older spelling of the same choice, still accepted
/// - label-offset: Further out from the spike the label sits (default: 0.35)
/// - style: Optional style overrides
#let brace(from, to, label: none, amplitude: 0.4, angle: auto, flip: none,
           label-offset: 0.35, style: auto) = {
  let p1 = as-point(from)
  let p2 = as-point(to)

  (
    type: "brace",
    p1: p1,
    p2: p2,
    label: label,
    amplitude: amplitude,
    angle: angle,
    flip: flip,
    "label-offset": label-offset,
    style: style,
  )
}

/// Check if object is a brace
#let is-brace(obj) = {
  type(obj) == dictionary and obj.at("type", default: none) == "brace"
}
