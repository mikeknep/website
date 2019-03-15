---
layout: post
title: "Demoing jekyll-lilypond-converter"
---

Below this sentence in the [raw markdown file](https://github.com/mikeknep/website/blob/source/_posts/2017-08-19-demoing-jlc.md) is a standard code block marked as `lilypond`, containing a C major chord.

```lilypond
\header {
  tagline=""
}

\paper {
  #(set-paper-size "a8landscape")
}

\relative {
  <c' e g>
}
```
