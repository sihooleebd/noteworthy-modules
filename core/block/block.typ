#import "../../../core/setup.typ": *
#import "../../../core/xref.typ": nw-anchor, nw-block-number, nw-block-caption
#let theorem-block(label, body, fill-color: white, stroke-color: black) = {
  v(box-margin)
  if block-design == "modern" {
    // Modern Design (Catalogue Style): Outlined, rounded, spacious
    block(
      fill: fill-color,
      stroke: 2pt + stroke-color,
      inset: 14pt,
      radius: 6pt,
      width: 100%,
      above: 1em,
      below: 1em,
    )[
      #text(weight: "bold", size: 11pt, fill: stroke-color, label)
      #v(8pt)
      #body
    ]
  } else {
    // Simple Design (Legacy): Filled, no border, Adlam font for title
    block(
      fill: fill-color,
      inset: box-inset,
      radius: 4pt,
      width: 100%,
      above: 1em,
      below: 1em,
    )[
      #text(size: 13pt, font: title-font, fill: stroke-color, weight: "bold")[#label]
      #v(5pt)
      #body
    ]
  }
}


#let create-block(config, ..args, label: none) = {
  let pos = args.pos()
  assert(
    1 <= pos.len() and pos.len() <= 3,
    message: "create-block must be called with (config, name, number, body), (config, name, body) or (config, body)",
  )
  [#std.metadata("block") <block-start>]
  let title = ""
  // `auto' means "keep counting"; a number given here replaces the last part
  // of the id, the way `solution' has always allowed.  The chapter and page
  // in front of it still come from the numbering scope.
  let given = auto
  let body = none
  if pos.len() == 3 {
    title = pos.at(0)
    given = pos.at(1)
    body = pos.at(2)
  } else if pos.len() == 2 {
    title = pos.at(0)
    body = pos.at(1)
  } else {
    body = pos.at(0)
  }
  let kind = lower(config.title)
  let number = nw-block-number(kind, given: given)
  // What the build's first pass will read back for the label map, and what
  // the heading shows: "Theorem 8.3.2 | Pythagoras".
  [#std.metadata((
    t: "block",
    kind: kind,
    label: if label == none { "" } else { label },
    title: title,
    num: if given == auto { "" } else { str(given) },
    // How this block numbers itself, so the build's first pass can reproduce
    // the same number rather than invent a different one.
    style: "scoped",
  )) <nw-mark>]
  let heading = [#text(smallcaps(config.title))#if number != none [ #number] | #title]
  // The anchor has to be real content at a real position -- that position is
  // where a cross-file link will land.
  let heading = nw-anchor(label, heading)
  theorem-block(heading, body, fill-color: config.fill, stroke-color: config.stroke)
}

#let create-solution(config, ..args, label: none) = {
  assert(
    1 <= args.pos().len() and args.pos().len() <= 3,
    message: "solution must be called with (config, name, number, body) or (config, name, body) or (config, body)",
  )
  let pos = args.pos()
  let number = none
  let body = none
  let name = ""

  if pos.len() == 1 {
    body = pos.at(0)
    number = auto
  } else if pos.len() == 2 {
    name = pos.at(0)
    body = pos.at(1)
    number = auto
  } else if pos.len() == 3 {
    name = pos.at(0)
    body = pos.at(2)
    number = pos.at(1)
  }

  [#std.metadata("solution") <solution>]

  let number-content = if number == auto {
    context {
      let sol-loc = here()
      let start-locs = query(selector(<block-start>).before(sol-loc))

      if start-locs.len() > 0 {
        let start-loc = start-locs.last().location()
        let sols = query(selector(<solution>).after(start-loc).before(sol-loc))
        [#sols.len()]
      } else {
        let sols = query(selector(<solution>).before(sol-loc))
        [#sols.len()]
      }
    }
  } else {
    number
  }

  if show-solution {
    [#std.metadata((
      t: "block",
      kind: "solution",
      label: if label == none { "" } else { label },
      title: name,
      num: if number == auto { "" } else { str(number) },
      style: "local",
    )) <nw-mark>]
    let heading = [#text(weight: "bold", config.title) #number-content | #name]
    theorem-block(nw-anchor(label, heading), body,
                  fill-color: config.fill, stroke-color: config.stroke)
  }
}

#let create-proof(config, ..args, label: none) = {
  assert(
    1 <= args.pos().len() and args.pos().len() <= 2,
    message: "create-proof must be called with (config, name, body) or (config, body)",
  )
  let name = ""
  let body = none
  if args.pos().len() == 2 {
    name = args.at(0)
    body = args.at(1)
  } else if args.pos().len() == 1 {
    body = args.at(0)
  }
  [#std.metadata((
    t: "block",
    kind: "proof",
    label: if label == none { "" } else { label },
    title: name,
    style: "none",
  )) <nw-mark>]
  let heading = [#text(weight: "bold", config.title) | #name]
  theorem-block(nw-anchor(label, heading), body,
                fill-color: config.fill, stroke-color: config.stroke)
}

#let analysis(..args) = {
  assert(
    1 <= args.pos().len() and args.pos().len() <= 2,
    message: "analysis must be called with (name, body) or (body)",
  )
  let name = ""
  let body = none
  if args.pos().len() == 2 {
    name = args.at(0)
    body = args.at(1)
  } else if args.pos().len() == 1 {
    body = args.at(0)
  }
  create-block(theme.blocks.analysis, name, body)
}
