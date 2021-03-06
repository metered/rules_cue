load(":common.bzl", _zip_src = "zip_src", _pkg_merge = "pkg_merge", _cue_deps_attr = "cue_deps_attr")

def _strip_extension(path):
    """Removes the final extension from a path."""
    components = path.split(".")
    components.pop()
    return ".".join(components)

def _cue_export_outputs(src, srcs, output_name, output_format):
    """Get map of cue_export outputs.
    Note that the arguments to this function are named after attributes on the rule.
    Args:
      src: The rule's `src` attribute
      output_name: The rule's `output_name` attribute
      output_format: The rule's `output_format` attribute
    Returns:
      Outputs for the cue_export
    """

    if not src:
        if len(srcs):
            src = srcs[0]
        elif not output_name:
            fail("must specify 'src', 'srcs', or 'output_name'")

    outputs = {
        "export": output_name or _strip_extension(src.name) + "." + output_format,
    }

    return outputs

_cue_export_attrs = {
    "src": attr.label(
        doc = "Cue entrypoint file",
        # mandatory = True,
        allow_single_file = [".cue"],
    ),
    "json": attr.string(),
    "srcs": attr.label_list(
        doc = "Cue entrypoint files",
        # mandatory = True,
        allow_files = [".cue"],
    ),
    "expression": attr.string(),
    "escape": attr.bool(
        default = False,
        doc = "Use HTML escaping.",
    ),
    "verbose": attr.bool(),
    "trace": attr.bool(),
    "all_errors": attr.bool(),
    
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
            "text",
            "cue",
        ],
    ),
    "inject": attr.string_dict(),
    "inject_files": attr.label_keyed_string_dict(),
    "data": attr.label_list(
        allow_files = True,
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

def _cue_export_impl(ctx):
    """_cue_export performs an action to export a single Cue file."""

    srcs = [ctx.file.src] if ctx.file.src else list(ctx.files.srcs)
    if ctx.attr.json:
        json_values_file = ctx.actions.declare_file("%s_values.json" % ctx.label.name)
        ctx.actions.write(json_values_file, ctx.attr.json)
        srcs.append(json_values_file)

    src_zip = _zip_src(ctx, srcs)
    merged = _pkg_merge(ctx, src_zip)

    output = ctx.outputs.export

    transitive_data = []

    for t in ctx.attr.data:
        transitive_data.append(t[DefaultInfo].files)

    # flatten & 'uniquify' our list of asset files
    data = depset(transitive = transitive_data).to_list()

    # The Cue CLI expects inputs like
    # cue export <flags> <input_filename>
    args = ctx.actions.args()

    args.add(ctx.executable._cue.path)
    args.add(merged.path)
    args.add(output.path)

    if ctx.attr.escape:
        args.add("--escape")
    #if ctx.attr.ignore:
    #    args.add("--ignore")
    #if ctx.attr.simplify:
    #    args.add("--simplify")
    if ctx.attr.all_errors:
       args.add("--all-errors")
    if ctx.attr.trace:
       args.add("--trace")
    if ctx.attr.verbose:
       args.add("--verbose")

    if ctx.attr.expression:
       args.add("--expression=%s" % ctx.attr.expression)

    for k, v in ctx.attr.inject.items():
        args.add("--inject", "%s=%s" % (k, ctx.expand_location(v, ctx.attr.data)))

    for k, v in ctx.attr.inject_files.items():
        args.add("--inject", "%s=$(cat %s)" % (v, k))

    args.add_joined(["--out", ctx.attr.output_format], join_with = "=")
    #args.add(input.path)

    args.add_all([f.basename for f in srcs])

    inputs = depset([merged] + data)

    ctx.actions.run_shell(
        mnemonic = "CueExport",
        tools = [ctx.executable._cue],
        arguments = [args],
        command = """
set -euo pipefail

CUE=$1; shift
PKGZIP=$1; shift
OUT=$1; shift

unzip -q ${PKGZIP}
set -x
exec ${CUE} export -o ${OUT} "$@"
""",
        inputs = inputs,
        outputs = [output],
        use_default_shell_env = True,
    )

    return [
        DefaultInfo(
            files = depset([ctx.outputs.export]),
            runfiles = ctx.runfiles(files = [ctx.outputs.export] + data),
        ),
    ]

_cue_export = rule(
    implementation = _cue_export_impl,
    attrs = _cue_export_attrs,
    outputs = _cue_export_outputs,
)

def _json_encode(o):
  # On next release...!
  # return json.encode_indent(o)

  json = struct(o=o).to_json()
  json = json[5:-1]
  return json

def cue_export(*, name, values=None, **kwargs):
    _json_values = None
    if values != None:
        _json_values = _json_encode(values)
        kwargs["json"] = _json_values

    _cue_export(name = name, **kwargs)