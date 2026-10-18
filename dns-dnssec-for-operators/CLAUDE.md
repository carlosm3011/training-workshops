# CLAUDE.md — dns-dnssec-for-operators

"DNS y DNSSEC para Operadores": a hands-on DNSSEC course for small/medium network operators (ISPs, IXPs, small TLDs, universities), covering signing, validation, key management (KASP in BIND) and troubleshooting. All content is written in **Spanish**, so keep new prose in Spanish. The shared build machinery and release process are described in the repo-root `CLAUDE.md`.

## Status

Released (v0.6.4). There are 7 modules (`01-Introduccion` … `07-DNSSEC-Avanzado`) plus `index.md` (preface and syllabus), and each module has a deck. When a module changes, keep its `.md`, its deck script and the PDF in sync.

## Notes

- The v0.6.0–v0.6.4 tags were created before the multi-course layout and are plain `vX.Y.Z`. `EXTRA_TAG_PATTERN := refs/tags/v*` in this course's Makefile keeps them in the title-page version history. New releases are tagged `dns-dnssec-for-operators/vX.Y.Z`.
- `slides/build_module01.py` predates `deck_helpers.py` and inlines its own copies of the helpers. Modules 02–07 import `deck_helpers`.
- Module 7 (NSEC3, the KASP rollover state machine, algorithm rollover, CDS/CDNSKEY, multi-signer) is the densest; its deck has 23 slides.
