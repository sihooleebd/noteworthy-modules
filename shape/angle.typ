// =====================================================
// ANGLE - Angle geometry object
// =====================================================

#import "point.typ": is-point, point
#import "core.typ": is-angle-value

/// Create an angle from three points (vertex in the middle)
/// The angle is measured from p1 to p2, going counterclockwise from vertex.
///
/// Parameters:
/// - p1: First point (one arm of the angle)
/// - vertex: The vertex point (where the angle is measured)
/// - p2: Second point (other arm of the angle)
/// - label: Optional label (e.g., $theta$)
/// - radius: Display radius for the arc marker (default: 0.5)
/// - style: Optional style overrides (color, fill)
///
/// The arms may be given as angles instead of points, with the vertex still
/// in the middle:
///   angle((1, 0), (0, 0), (0, 1))                  // through two points
///   angle(0deg, (0, 0), 60deg, radius: 2.5)        // by angle
///
/// Angles are taken literally -- the sweep runs counterclockwise from the
/// first to the second, so 0deg to 300deg is the 300deg one.  Pass `reflex'
/// to override that.
#let angle(p1, vertex, p2, label: none, radius: 0.5, label-radius: auto, fill: auto, style: auto, reflex: "auto") = {
  let vtx = if is-point(vertex) { vertex } else { point(vertex.at(0), vertex.at(1)) }

  // Angle form: arms are directions, and only their direction is drawn, so
  // put a point one unit out along each.
  let by-angle = is-angle-value(p1) or is-angle-value(p2)
  if by-angle {
    assert(
      is-angle-value(p1) and is-angle-value(p2),
      message: "angle: give both arms as angles, or both as points",
    )
    let arm = a => point(vtx.x + calc.cos(a), vtx.y + calc.sin(a))
    return (
      type: "angle",
      p1: arm(p1),
      vertex: vtx,
      p2: arm(p2),
      label: label,
      radius: radius,
      "label-radius": label-radius,
      fill: fill,
      style: style,
      // "auto" would fold a sweep past 180deg back on itself, which is not
      // what someone who wrote the two angles out meant.
      reflex: if reflex == "auto" { false } else { reflex },
    )
  }

  let pt1 = if is-point(p1) { p1 } else { point(p1.at(0), p1.at(1)) }
  let pt2 = if is-point(p2) { p2 } else { point(p2.at(0), p2.at(1)) }

  (
    type: "angle",
    p1: pt1,
    vertex: vtx,
    p2: pt2,
    label: label,
    radius: radius,
    "label-radius": label-radius,
    fill: fill,
    style: style,
    reflex: reflex,
  )
}

/// Create a right angle marker (90°)
///
/// Parameters:
/// - p1: First point
/// - vertex: The vertex point
/// - p2: Second point
/// - radius: Size of the right angle marker (default: 0.3)
#let right-angle(p1, vertex, p2, radius: 0.3, style: auto) = {
  let pt1 = if is-point(p1) { p1 } else { point(p1.at(0), p1.at(1)) }
  let vtx = if is-point(vertex) { vertex } else { point(vertex.at(0), vertex.at(1)) }
  let pt2 = if is-point(p2) { p2 } else { point(p2.at(0), p2.at(1)) }

  (
    type: "right-angle",
    p1: pt1,
    vertex: vtx,
    p2: pt2,
    radius: radius,
    style: style,
  )
}

/// Create an angle from two lines that share a point
///
/// Parameters:
/// - l1: First line
/// - l2: Second line
/// - label: Optional label
/// - radius: Display radius
#let angle-between-lines(l1, l2, label: none, radius: 0.5, style: auto) = {
  // Find intersection point (vertex)
  // For now, assume they share p1
  let vertex = l1.p1

  // Use the other endpoints as the arms
  let pt1 = l1.p2
  let pt2 = l2.p2

  angle(pt1, vertex, pt2, label: label, radius: radius, style: style)
}

/// Check if object is an angle
#let is-angle(obj) = {
  type(obj) == dictionary and obj.at("type", default: none) == "angle"
}

/// Check if object is a right angle marker
#let is-right-angle(obj) = {
  type(obj) == dictionary and obj.at("type", default: none) == "right-angle"
}

/// Calculate the angle measure in radians
#let angle-measure(ang) = {
  let dx1 = ang.p1.x - ang.vertex.x
  let dy1 = ang.p1.y - ang.vertex.y
  let dx2 = ang.p2.x - ang.vertex.x
  let dy2 = ang.p2.y - ang.vertex.y

  let angle1 = calc.atan2(dx1, dy1)
  let angle2 = calc.atan2(dx2, dy2)

  let diff = angle2 - angle1
  // Normalize to [0, 2π)
  if diff < 0rad { diff + 2 * calc.pi * 1rad } else { diff }
}

/// Get the start angle (from positive x-axis)
#let angle-start(ang) = {
  let dx = ang.p1.x - ang.vertex.x
  let dy = ang.p1.y - ang.vertex.y
  calc.atan2(dx, dy)
}

/// Get the end angle (from positive x-axis)
#let angle-end(ang) = {
  let dx = ang.p2.x - ang.vertex.x
  let dy = ang.p2.y - ang.vertex.y
  calc.atan2(dx, dy)
}
