load(":providers.bzl", "CuePkgInfo")

cue_deps_attr = attr.label_list(
    doc = "cue_library targets to include in the evaluation",
    providers = [CuePkgInfo],
    allow_files = False,
)

def zip_src(ctx, srcs):
    # Generate a zip file containing the src file

    zipper_list_content = "".join([src.basename + "=" + src.path + "\n" for src in srcs])
    zipper_list = ctx.actions.declare_file(ctx.label.name + "~zipper.txt")
    ctx.actions.write(zipper_list, zipper_list_content)

    src_zip = ctx.actions.declare_file(ctx.label.name + "~src.zip")

    args = ctx.actions.args()
    args.add("c")
    args.add(src_zip.path)
    args.add("@" + zipper_list.path)

    ctx.actions.run(
        mnemonic = "zipper",
        executable = ctx.executable._zipper,
        arguments = [args],
        inputs = [zipper_list] + srcs,
        outputs = [src_zip],
        use_default_shell_env = True,
    )

    return src_zip

def pkg_merge(ctx, src_zip):
    merged = ctx.actions.declare_file(ctx.label.name + "~merged.zip")

    args = ctx.actions.args()
    args.add_joined(["-o", merged.path], join_with = "=")
    inputs = depset(
        [src_zip],
        transitive = [dep[CuePkgInfo].transitive_pkgs for dep in ctx.attr.deps],
        # Provide .cue sources from dependencies first
        order = "postorder",
    )
    for dep in inputs.to_list():
        args.add(dep.path)

    ctx.actions.run(
        mnemonic = "CuePkgMerge",
        executable = ctx.executable._zipmerge,
        arguments = [args],
        inputs = inputs,
        outputs = [merged],
        use_default_shell_env = True,
    )

    return merged
