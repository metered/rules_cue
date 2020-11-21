# define a new rule factory that accepts a provider (e.g. PushInfo) and defines a rule that expects this from srcs and does a "cue import" with it.


def _impl(repository_ctx):
  rule_name = repository_ctx.attr.name

  repository_ctx.file(
    "BUILD.bazel",
    executable = False,
    content = "",
  )
  
  repository_ctx.file(
    "index.bzl",
    executable = False,
    content = """
load("{provider_path}", "{provider}")
load("@com_github_tnarg_rules_cue//cue:cue.bzl", _cue_import = "cue_import")

def _json_repr(o):
  # On next release...!
  # return json.encode_indent(o)

  json = struct(o=o).to_json()
  json = json[5:-1]
  return json

def _walk(value, cursor):
  files = []
  for c in cursor:
    t = type(value)
    if t == 'File':
      files.append(value)

    if t == 'dict':
      value = value[c]
    elif t == 'list':
      value = value[int(c)]
    else:
      value = getattr(value, c)

  if type(value) == 'File':
    files.append(value)
  return [value, files]

def _impl(ctx):
  src = ctx.attr.src
  content_publisher_executables = [src.files_to_run.executable]
  content_publisher_runfiles = [src.default_runfiles.files]

  src_provider = src[{provider}]
  fields = ctx.attr.fields
  file_fields = ctx.attr.file_fields

  args = []
  args += ["--output", ctx.outputs.json.path]
  inputs = []
  for field, cursor in fields.items():
    value, _ = _walk(src_provider, cursor)
    args += ["--put_json", field, _json_repr(value)]

  for field, cursor in file_fields.items():
    value, files = _walk(src_provider, cursor)
    print("typevalue", type(value), value)
    inputs.extend(files)
    args += ["--put_file", field, value.path]

  ctx.actions.run(
    outputs = [ctx.outputs.json],
    inputs = inputs,
    arguments = args,
    executable = ctx.executable._renderer
  )

  return [
    DefaultInfo(
      files = depset([ctx.outputs.json])
    ),
    # We need to do this so that rules_terraform can trigger things like "docker push"
    OutputGroupInfo(
      content_publisher_executables = depset(direct = content_publisher_executables),
      content_publisher_runfiles = depset(transitive = content_publisher_runfiles),
    ),
  ]

def _outputs(name):
  return dict(
    json = "%s.json" % name,
  )

_json_rule = rule(
  implementation = _impl,
  attrs = dict(
    src = attr.label(
      mandatory = True,
      providers = [{provider}],
    ),
    fields = attr.string_list_dict(
      default = {fields} or {{}},
    ),
    file_fields = attr.string_list_dict(
      default = {file_fields} or {{}},
    ),
    _renderer = attr.label(
      default = Label("{renderer}"),
      executable = True,
      cfg = "host",
    )
  ),
  outputs = _outputs,
)

def {rule_name}(*,
  name,
  src,
  fields = None,
  file_fields = None,
  importpath = None,
  package = None,
):
  _json_rule(
    name = "%s_json" % name,
    src = src,
    fields = fields,
    file_fields = file_fields,
  )

  _cue_import(
    name = name,
    srcs = [
      ":%s_json" % name,
    ],
    package = package,
    importpath = importpath,
  )
""".format(
      provider_path = repository_ctx.attr.provider_path,
      provider = repository_ctx.attr.provider,
      rule_name = rule_name,
      fields = repr(repository_ctx.attr.fields),
      file_fields = repr(repository_ctx.attr.file_fields),
      renderer = "@com_github_tnarg_rules_cue//cue:render_json",
    )
  )

def_cue_rule = repository_rule(
  implementation = _impl,
  attrs = {
    "provider_path": attr.string(
      mandatory = True,
    ),
    "provider": attr.string(
      mandatory = True,
    ),
    "fields": attr.string_list_dict(
      # mandatory = True,
    ),
    "file_fields": attr.string_list_dict(
      # mandatory = True,
    ),
  },
)
