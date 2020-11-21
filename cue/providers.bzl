CuePkgInfo = provider(
    doc = "Collects files from cue_library for use in downstream cue_export",
    fields = {
        "transitive_pkgs": "Cue pkg zips for this target and its dependencies",
    },
)
