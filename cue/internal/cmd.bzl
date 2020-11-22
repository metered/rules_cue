load(":common.bzl", _zip_src = "zip_src", _pkg_merge = "pkg_merge", _cue_deps_attr = "cue_deps_attr")

def _cue_cmd_outputs(output_name):
    """Get map of cue_cmd outputs.
    Note that the arguments to this function are named after attributes on the rule.
    Args:
      output_name: The rule's `output_name` attribute
    Returns:
      Outputs for the cue_cmd
    """

    outputs = {
        "export": output_name,
    }

    return outputs

_cue_cmd_attrs = {
    "srcs": attr.label_list(
        doc = "Cue entrypoint files",
        # mandatory = True,
        allow_files = [".cue"],
    ),
    "verbose": attr.bool(),
    "trace": attr.bool(),
    
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
    "cmd": attr.string(
        mandatory = True,
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

def _cue_cmd_impl(ctx):
    """_cue_cmd performs an action to export a single Cue file."""

    srcs = ctx.files.srcs
    src_zip = _zip_src(ctx, srcs)
    merged = _pkg_merge(ctx, src_zip)

    output = ctx.outputs.export

    transitive_data = []

    for t in ctx.attr.data:
        transitive_data.append(t[DefaultInfo].files)

    # flatten & 'uniquify' our list of asset files
    data = depset(transitive = transitive_data).to_list()

    # The Cue CLI expects inputs like
    # cue cmd <input_filename> <flags>
    args = ctx.actions.args()

    args.add(ctx.executable._cue.path)
    args.add(merged.path)
    args.add(output.path)

    #if ctx.attr.ignore:
    #    args.add("--ignore")
    #if ctx.attr.simplify:
    #    args.add("--simplify")
    if ctx.attr.trace:
       args.add("--trace")
    if ctx.attr.verbose:
       args.add("--verbose")

    for k, v in ctx.attr.inject.items():
        args.add("--inject", "%s=%s" % (k, ctx.expand_location(v, ctx.attr.data)))

    for k, v in ctx.attr.inject_files.items():
        args.add("--inject", "%s=$(cat %s)" % (v, k))

    args.add(ctx.attr.cmd)

    # args.add_all([f.basename for f in ctx.files.srcs])

    inputs = depset([merged] + data)

    ctx.actions.run_shell(
        mnemonic = "CueCmd",
        tools = [ctx.executable._cue],
        arguments = [args],
        command = """
set -euo pipefail

set -x
env

CUE=$1; shift
PKGZIP=$1; shift
OUT=$1; shift

unzip -q ${PKGZIP}
find .
exec ${CUE} cmd "$@" > ${OUT}
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

cue_cmd = rule(
    implementation = _cue_cmd_impl,
    attrs = _cue_cmd_attrs,
    outputs = _cue_cmd_outputs,
)
