# CLAUDE.md — bgp-101-intro-for-operators

"BGP 101: A Practical Guide to the Border Gateway Protocol", by Carlos M. Martinez (XT6 Labs). It's a hands-on BGP course using FRR and Containerlab. All content is in **English**. The shared build machinery and release process are described in the repo-root `CLAUDE.md`.

## Structure

- Two PDFs come from one set of sources, one Quarto profile each:
  - `_quarto-book.yml` lists the theory chapters (01–03, 05–06, 08–09).
  - `_quarto-labguide.yml` lists the labs (04, 07, 10, 11) and renders to `_book/labguide/`.
  - Shared settings live in `_quarto.yml`, which must not list chapters.
  - A new chapter goes in exactly one profile's list; `index.md` goes in both.
- `index.md` (the preface of both PDFs) is built from `README.md`'s introduction and references. If you change one, update the other.
- `labs/` holds the labs, one directory each: `lab-N/lab-N.clab.yml` (topology), `configs/<node>.conf` (starting config: interfaces, plus full config for routers students don't operate) and `solution/<node>.conf` (finished config, applied by `labs/load-solution.sh` with `vtysh -f`). `labs/daemons` and `labs/vtysh.conf` are shared by every node. The image is pinned to `quay.io/frrouting/frr:10.7.1` (Docker Hub's `frrouting/frr` stopped at 8.4). Configs are mounted read-only because `write memory` on a bind-mounted file truncates it on the host.
- Lab output in the chapters is real FRR output; if you change a lab, re-run it and update the output. The labs use documentation/benchmark ranges (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24, 198.18.0.0/15) as if public, 10.255.0.N/32 loopbacks, and `ip forwarding` in every router config (FRR doesn't enable forwarding otherwise).
- `references/` holds source material and is not part of the build.
- `title-page.tex.in` also keeps every code block on a single page (carried over from the old pandoc build), so keep code blocks shorter than a page.
- There are no slide decks yet (`SLIDE_MODULES` is unset).
