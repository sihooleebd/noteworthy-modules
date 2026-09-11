#import "../../../core/setup.typ": *
#import "../../../core/xref.typ": nw-anchor, nw-block-number, nw-block-caption, nw-in-block, nw-solution-number, nw-caption
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
  let heading = [#text(smallcaps(config.title))#if number != none [ #number]#if title != "" [ | #title]#nw-caption(label, kind, title, given)]
  // The anchor has to be real content at a real position -- that position is
  // where a cross-file link will land.
  let heading = nw-anchor(label, heading)
  theorem-block(heading, nw-in-block(body),
                fill-color: config.fill, stroke-color: config.stroke)
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

  // Counted within the block that is actually open, which the stack knows.
  // The old reading -- `<solution>' elements since the last `<block-start>'
  // -- had no way to tell, because nothing marked where a block ended.
  let number-content = nw-solution-number(name: label, given: number)

  if show-solution {
    [#std.metadata((
      t: "block",
      kind: "solution",
      label: if label == none { "" } else { label },
      title: name,
      num: if number == auto { "" } else { str(number) },
      style: "local",
    )) <nw-mark>]
    let heading = [#text(weight: "bold", config.title) #number-content#if name != "" [ | #name]]
    theorem-block(nw-anchor(label, heading), nw-in-block(body),
                  fill-color: config.fill, stroke-color: config.stroke)
  }
}

#let create-proof(config, ..args, label: none) = {
  let pos = args.pos()
  assert(
    1 <= pos.len() and pos.len() <= 3,
    message: "create-proof must be called with (config, name, number, body), (config, name, body) or (config, body)",
  )
  let name = ""
  let given = auto
  let body = none
  if pos.len() == 3 {
    name = pos.at(0)
    given = pos.at(1)
    body = pos.at(2)
  } else if pos.len() == 2 {
    name = pos.at(0)
    body = pos.at(1)
  } else {
    body = pos.at(0)
  }
  // Numbered like any other block.  It used to print none at all, which read
  // as a gap beside a numbered theorem and, worse, left a labelled proof with
  // nothing to be referenced by: an unnamed one came out as bare "Proof".
  let number = nw-block-number("proof", given: given)
  [#std.metadata((
    t: "block",
    kind: "proof",
    label: if label == none { "" } else { label },
    title: name,
    num: if given == auto { "" } else { str(given) },
    style: "scoped",
  )) <nw-mark>]
  let heading = [#text(weight: "bold", config.title)#if number != none [ #number]#if name != "" [ | #name]#nw-caption(label, "proof", name, given)]
  theorem-block(nw-anchor(label, heading), nw-in-block(body),
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
