load(":import.bzl", _cue_import = "cue_import")
load(":library.bzl", _cue_library = "cue_library")
load(":cmd.bzl", _cue_cmd = "cue_cmd")
load(":export.bzl", _cue_export = "cue_export")

cue_import = _cue_import
cue_library = _cue_library
cue_cmd = _cue_cmd
cue_export = _cue_export

# def _collect_transitive_pkgs(pkg, deps):
#     "Cue evaluation requires all transitive .cue source files"
#     return depset(
#         [pkg],
#         transitive = [dep[CuePkgInfo].transitive_pkgs for dep in deps],
#         # Provide .cue sources from dependencies first
#         order = "postorder",
#     )
