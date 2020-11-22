load(":common.bzl", _zip_src = "zip_src", _pkg_merge = "pkg_merge", _cue_deps_attr = "cue_deps_attr")

def _strip_extension(path):
    """Removes the final extension from a path."""
    components = path.split(".")
    components.pop()
    return ".".join(components)

def _cue_export(ctx, merged, output):
    """_cue_export performs an action to export a single Cue file."""

    # The Cue CLI expects inputs like
    # cue export <flags> <input_filename>
    args = ctx.actions.args()

    args.add(ctx.executable._cue.path)
    args.add(merged.path)
    args.add(ctx.file.src.basename)
    args.add(output.path)

    if ctx.attr.escape:
        args.add("--escape")
    #if ctx.attr.ignore:
    #    args.add("--ignore")
    #if ctx.attr.simplify:
    #    args.add("--simplify")
    #if ctx.attr.trace:
    #    args.add("--trace")
    #if ctx.attr.verbose:
    #    args.add("--verbose")
    #if ctx.attr.debug:
    #    args.add("--debug")

    args.add_joined(["--out", ctx.attr.output_format], join_with = "=")
    #args.add(input.path)

    ctx.actions.run_shell(
        mnemonic = "CueExport",
        tools = [ctx.executable._cue],
        arguments = [args],
        command = """
set -euo pipefail

CUE=$1; shift
PKGZIP=$1; shift
SRC=$1; shift
OUT=$1; shift

unzip -q ${PKGZIP}
${CUE} export -o ${OUT} $@ ${SRC}
""",
        inputs = [merged],
        outputs = [output],
        use_default_shell_env = True,
    )

def _cue_export_impl(ctx):
    src_zip = _zip_src(ctx, [ctx.file.src])
    merged = _pkg_merge(ctx, src_zip)
    _cue_export(ctx, merged, ctx.outputs.export)
    return DefaultInfo(
        files = depset([ctx.outputs.export]),
        runfiles = ctx.runfiles(files = [ctx.outputs.export]),
    )

def _cue_export_outputs(src, output_name, output_format):
    """Get map of cue_export outputs.
    Note that the arguments to this function are named after attributes on the rule.
    Args:
      src: The rule's `src` attribute
      output_name: The rule's `output_name` attribute
      output_format: The rule's `output_format` attribute
    Returns:
      Outputs for the cue_export
    """

    outputs = {
        "export": output_name or _strip_extension(src.name) + "." + output_format,
    }

    return outputs

_cue_export_attrs = {
    "src": attr.label(
        doc = "Cue entrypoint file",
        mandatory = True,
        allow_single_file = [".cue"],
    ),
    "escape": attr.bool(
        default = False,
        doc = "Use HTML escaping.",
    ),
    #debug            give detailed error info
    #ignore           proceed in the presence of errors
    #simplify         simplify output
    #trace            trace computation
    #verbose          print information about progress
    "output_name": attr.string(
        doc = """Name of the output file, including the extension.
By default, this is based on the `src` attribute: if `foo.cue` is
the `src` then the output file is `foo.json.`.
You can override this to be any other name.
Note that some tooling may assume that the output name is derived from
the input name, so use this attribute with caution.""",
        default = "",
    ),
    "output_format": attr.string(
        doc = "Output format",
        default = "json",
        values = [
            "json",
            "yaml",
        ],
    ),
    "deps": _cue_deps_attr,
    "_cue": attr.label(
        default = Label("//cue:cue_runtime"),
        executable = True,
        allow_single_file = True,
        cfg = "host",
    ),
    "_zipper": attr.label(
        default = Label("@bazel_tools//tools/zip:zipper"),
        executable = True,
        allow_single_file = True,
        cfg = "host",
    ),
    "_zipmerge": attr.label(
        default = Label("@io_rsc_zipmerge//:zipmerge"),
        executable = True,
        allow_single_file = True,
        cfg = "host",
    )
}

cue_export = rule(
    implementation = _cue_export_impl,
    attrs = _cue_export_attrs,
    outputs = _cue_export_outputs,
)
