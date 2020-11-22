load("//cue:providers.bzl", "CuePkgInfo")
load(":common.bzl", _zip_src = "zip_src", _pkg_merge = "pkg_merge", _cue_deps_attr = "cue_deps_attr")

def _cue_def(ctx):
    "Cue def library"
    srcs_zip = _zip_src(ctx, ctx.files.srcs)
    merged = _pkg_merge(ctx, srcs_zip)
    def_out = ctx.actions.declare_file(ctx.label.name + "~def.json")

    args = ctx.actions.args()
    args.add(ctx.executable._cue.path)
    args.add(merged.path)
    args.add(def_out.path)

    ctx.actions.run_shell(
        mnemonic = "CueDef",
        tools = [ctx.executable._cue],
        arguments = [args],
        command = """
set -euo pipefail

CUE=$1; shift
PKGZIP=$1; shift
OUT=$1; shift

unzip -q ${PKGZIP}
${CUE} def -o ${OUT}
""",
        inputs = [merged],
        outputs = [def_out],
        use_default_shell_env = True,
    )

    return def_out

def _cue_library_impl(ctx):
    """cue_library validates a cue package, bundles up the files into a
    zip, and collects all transitive dep zips.
    Args:
      ctx: The Bazel build context
    Returns:
      The cue_library rule.
    """

    def_out = _cue_def(ctx)

    # Create the manifest input to zipper
    pkg = "pkg/"+ctx.attr.importpath.split(":")[0]
    manifest = "".join([pkg+"/"+src.basename + "=" + src.path + "\n" for src in ctx.files.srcs])
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
        inputs = [def_out, manifest_file] + ctx.files.srcs,
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
                transitive = [dep[CuePkgInfo].transitive_pkgs for dep in ctx.attr.deps],
                # Provide .cue sources from dependencies first
                order = "postorder",
            ),
        ),
    ]

_cue_library_attrs = {
    "srcs": attr.label_list(
        doc = "Cue source files",
        allow_files = [".cue"],
        allow_empty = False,
        mandatory = True,
    ),
    "deps": _cue_deps_attr,
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

cue_library = rule(
    implementation = _cue_library_impl,
    attrs = _cue_library_attrs,
)
