final: prev:

# bcachefs-tools pinned to the 2026-10-06 master snapshot that follows the
# v1.39.7 tag: it carries the erasure-coding fixes the tag lacks (RAID6
# two-block recovery past the first page, a stripe update resumed after a crash
# re-keying extents into the wrong block, a reconstruct racing a stripe
# deletion returning EIO) plus two scrub accounting fixes, and stops before the
# fsck-in-Rust conversion that began that evening. The cherry-picks do not apply
# to the tag on their own because the EC code was reworked in between. The
# out-of-tree kernel module is built from this same source.
{
  bcachefs-tools = prev.bcachefs-tools.overrideAttrs (old: rec {
    version = "1.39.7-unstable-2026-10-06";
    src = final.fetchFromGitHub {
      owner = "koverstreet";
      repo = "bcachefs-tools";
      rev = "4aaceb395dca4762e3915b4a0e2971598535d640";
      hash = "sha256-dc5BfQxv/2bACb4e+FdEk1kYWd4SVMHQMSn9dQlSqVQ=";
    };
    cargoDeps = final.rustPlatform.fetchCargoVendor {
      inherit src;
      hash = "sha256-4ZStyYaT+6Suup1ue2wFFCTAlnsnEO9WaUJHe47BKXY=";
    };
  });
}
