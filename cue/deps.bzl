load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_gazelle//:deps.bzl", "go_repository")

_cue_runtimes = {
    "0.3.0-alpha5": [
        {
            "os": "Linux",
            "arch": "x86_64",
            "sha256": "9d3131e470cdb5182afd9966688f1c052d383145cce005a947156b5591da39b7",
        },
        {
            "os": "Darwin",
            "arch": "x86_64",
            "sha256": "1b9815a00d0afc305c8a4cc40f2b78dc440ce9047f1778d933c330675de0a690",
        },
        {
            "os": "Windows",
            "arch": "x86_64",
            "sha256": "936084adace91705b4e3720d3f54b3a6156d1e2d8662f5bbb1b79fe8afcb2dae",
        },
    ],
    "0.2.2": [
        {
            "os": "Linux",
            "arch": "x86_64",
            "sha256": "810851e0e7d38192a6d0e09a6fa89ab5ff526ce29c9741f697995601edccb134",
        },
        {
            "os": "Darwin",
            "arch": "x86_64",
            "sha256": "d782602b0387d19cb004eab90b47d51bb207007396450153af751ce7581228be",
        },
        {
            "os": "Windows",
            "arch": "x86_64",
            "sha256": "062d17ea61eec8065af02433277ef42833fc8f139202c5743c31bcf316c0431a",
        },
    ],
    "0.2.0": [
        {
            "os": "Linux",
            "arch": "x86_64",
            "sha256": "36c454c8ab48e3fe1d0bb10a461b8b4e362566b50048a5e2808e221248f373d5",
        },
        {
            "os": "Darwin",
            "arch": "x86_64",
            "sha256": "f38412b855bf5c3b97d2c7358ebaaccc088b707158809bd0fce889bbe050ba61",
        },
        {
            "os": "Windows",
            "arch": "x86_64",
            "sha256": "2d1d7f45c61808ba83692f1aefe804894e19d032aec06a91475cb5923bfa6bc4",
        },
    ],
    "0.1.2": [
        {
            "os": "Linux",
            "arch": "x86_64",
            "sha256": "ad47b69a43197af7a150974969ff51034aa981b4df264c0221dbcc3737280209",
        },
        {
            "os": "Darwin",
            "arch": "x86_64",
            "sha256": "0580c7db622eabfcec8f7946bbd7819b7d38ebf11ac79f918d2deccc3544d443",
        },
        {
            "os": "Windows",
            "arch": "x86_64",
            "sha256": "f24e8ff652ae3bdc5ceca09901570f9894f27c75ce94ee67f0c37544ae5a3c75",
        },
    ],
    "0.1.1": [
        {
            "os": "Linux",
            "arch": "x86_64",
            "sha256": "6405bc947cdd5fbee6f6af4b440000503e548cb45a689c0cb72846bc7a694c9e",
        },
        {
            "os": "Darwin",
            "arch": "x86_64",
            "sha256": "4e4d977bdc41cfa61335dcce8d14b535cde08bdafeb7ea81b81bc6b7ced94cbf",
        },
        {
            "os": "Windows",
            "arch": "x86_64",
            "sha256": "110b0a3b8210142fae362ec4c72481f0d63a0240edf88b4c14a3cb216271878a",
        },
    ]
}

def cue_register_toolchains(version = "0.3.0-alpha5"):
    for platform in _cue_runtimes[version]:
        suffix = "tar.gz"
        if platform["os"] == "Windows":
            suffix = "zip"
        http_archive(
            name = "cue_runtime_%s_%s" % (platform["os"].lower(), platform["arch"]),
            build_file_content = """exports_files(["cue"], visibility = ["//visibility:public"])""",
            url = "https://github.com/cuelang/cue/releases/download/v%s/cue_%s_%s_%s.%s" % (version, version, platform["os"], platform["arch"], suffix),
            sha256 = platform["sha256"],
        )

def cue_rules_dependencies():
    go_repository(
        name = "com_github_cockroachdb_apd_v2",
        importpath = "github.com/cockroachdb/apd/v2",
        sum = "h1:y1Rh3tEU89D+7Tgbw+lp52T6p/GJLpDmNvr10UWqLTE=",
        version = "v2.0.1",
    )

    go_repository(
        name = "com_github_mpvl_unique",
        importpath = "github.com/mpvl/unique",
        sum = "h1:D5x39vF5KCwKQaw+OC9ZPiLVHXz3UFw2+psEX+gYcto=",
        version = "v0.0.0-20150818121801-cbe035fff7de",
    )

    go_repository(
        name = "com_github_pkg_errors",
        importpath = "github.com/pkg/errors",
        sum = "h1:iURUrRGxPUNPdy5/HRSm+Yj6okJ6UtLINN0Q9M4+h3I=",
        version = "v0.8.1",
    )

    go_repository(
        name = "org_cuelang_go",
        importpath = "cuelang.org/go",
        sum = "h1:RIZpXgS3nw+hWFDbxm5peKo3XHIDJTpcaS9TCmpcVrA=",
        version = "v0.1.1",
    )

    go_repository(
        name = "org_golang_x_xerrors",
        importpath = "golang.org/x/xerrors",
        sum = "h1:E7g+9GITq07hpfrRu66IVDexMakfv52eLZ2CXBWiKr4=",
        version = "v0.0.0-20191204190536-9bdfabe68543",
    )

    go_repository(
        name = "com_github_iancoleman_strcase",
        importpath = "github.com/iancoleman/strcase",
        sum = "h1:VHgatEHNcBFEB7inlalqfNqw65aNkM1lGX2yt3NmbS8=",
        version = "v0.0.0-20191112232945-16388991a334",
    )

    go_repository(
        name = "io_rsc_zipmerge",
        importpath = "rsc.io/zipmerge",
        sum = "h1:SQ3COGthAQ0mTF+xfVFKwmYag+U/QmnUVhNs4YEP8hQ=",
        version = "v0.0.0-20160407035457-24e6c1052c64",
    )
