# Bubble license and publication policy validation

Date: 2026-09-10

## Scope

The repository's existing MIT License applies to plumOS-Bubble-authored
software and documentation. It does not relicense separately authored vendor
or third-party material.

The maintainer attests that the GKD Bubble vendor granted permission to use and
redistribute the stockOS-derived files required by plumOS-Bubble. No separate
written vendor license file was issued. The repository records GKD ownership,
the vendor-permission basis, the public plumOS-GKD reference and the continuing
rights of third-party licensors, including Arm Mali.

DraStic follows the same narrow release policy as plumOS-MF: steward-fu/nds
integration remains LGPL-2.1-only, while the separately authored DraStic
executable is an explicitly allowlisted project-approved inclusion and is not
relicensed by LGPL or MIT.

## Machine gates

`scripts/audit-bubble-vendor-artifacts.py --require-publishable` passed with:

```text
bubble_vendor_audit=result-ok inputs=5 checked_local=26 private_only=0 publishable=1
```

Negative fixtures also passed: a reintroduced `private-validation-only` input
is rejected, and `project-approved-inclusion` is rejected for every artifact
except the explicitly allowlisted DraStic id.

The app layer was assembled again and its global checksum verification passed.
Its manifest now reports `publishable=true`, an empty
`non_publishable_reasons` array, and `release_complete=false`. The latter stays
false because clean-clone content checks, physical release-candidate acceptance
and explicit publication approval remain separate release gates.

No release was published by this change.
