// =====================================================
// SURFACE - A function of two parameters, plotted in space
// =====================================================
//
// Here rather than in `shape' because of what it is given: a function and
// the domains to sample it over, exactly as `func' and `parametric' are.
// Everything in `shape' is fixed by points and radii; everything defined by
// sampling a function is plotting, and lives here.
//
// It is drawn by `space-canvas', which owns the camera -- this only says
// which surface, the same way `func' says which curve.

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
#let surface(
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
