load(":providers.bzl", "CuePkgInfo")

def _cue_import(ctx, package, inputs, output):
    """_cue_import performs an action to import a list of JSON or YAML files."""

    # The Cue CLI expects inputs like
    # cue import <flags> <input_filenames ...>
    args = ctx.actions.args()
    args.add("import")

    #if ctx.attr.ignore:
    #    args.add("--ignore")
    #if ctx.attr.simplify:
    #    args.add("--simplify")
    #if ctx.attr.trace:
    #    args.add("--trace")
    #if ctx.attr.verbose:
    #    args.add("--verbose")

    args.add("--outfile", output.path)

    if package:
        args.add("--package", package)
    if ctx.attr.path:
        args.add("--path", ctx.attr.path)
    if ctx.attr.recursive:
        args.add("--recursive")

    args.add_all(inputs)

    ctx.actions.run(
        mnemonic = "CueImport",
        arguments = [args],
        inputs = inputs,
        executable = ctx.executable._cue,
        outputs = [output],
    )

def _cue_import_impl(ctx):
    """cue_import validates a cue package, bundles up the files into a
    zip, and collects all transitive dep zips.
    Args:
      ctx: The Bazel build context
    Returns:
      The cue_import rule.
    """

    cue_out = ctx.actions.declare_file(ctx.label.name + ".cue")
    package = ctx.attr.importpath.split(":", 2)[1]

    _cue_import(ctx, package, ctx.files.srcs, cue_out)

    # Create the manifest input to zipper
    pkg = "pkg/"+ctx.attr.importpath.split(":")[0]

    outs = [cue_out]
    manifest = "".join([pkg+"/"+cue_out.basename + "=" + out.path + "\n" for out in outs])
    manifest_file = ctx.actions.declare_file(ctx.label.name + "~manifest")
    ctx.actions.write(manifest_file, manifest)

    pkg = ctx.actions.declare_file(ctx.label.name + ".zip")

    args = ctx.actions.args()
    args.add("c")
    args.add(pkg.path)
    args.add("@" + manifest_file.path)

    ctx.actions.run(
        mnemonic = "CuePkg",
        outputs = [pkg],
        inputs = [manifest_file, cue_out],
        executable = ctx.executable._zipper,
        arguments = [args],
    )

    return [
        DefaultInfo(
            files = depset([pkg]),
            runfiles = ctx.runfiles(files = [pkg]),
        ),
        CuePkgInfo(
            transitive_pkgs = depset(
                [pkg],
                # Provide .cue sources from dependencies first
                order = "postorder",
            ),
        ),
    ]

_cue_import_attrs = {
    "srcs": attr.label_list(
        doc = "Cue source files",
        allow_files = [".json", ".yaml"],
        allow_empty = False,
        mandatory = True,
    ),
    "path": attr.string(),
    "package": attr.string(),
    "recursive": attr.bool(),
    "importpath": attr.string(
        doc = "Cue import path under pkg/",
        mandatory = True,
    ),
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
    ),
}

cue_import = rule(
    implementation = _cue_import_impl,
    attrs = _cue_import_attrs,
)
