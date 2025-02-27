"""General-purpose rule to create tar archives.

Unlike [pkg_tar from rules_pkg](https://github.com/bazelbuild/rules_pkg/blob/main/docs/latest.md#pkg_tar)
this:

- Does not depend on any Python interpreter setup
- The "manifest" specification is a mature public API and uses a compact tabular format, fixing
  https://github.com/bazelbuild/rules_pkg/pull/238
- Does not have any custom program to produce the output, instead
  we rely on a well-known C++ program called "tar".
  Specifically, we use the BSD variant of tar since it provides a means
  of controlling mtimes, uid, symlinks, etc.

We also provide full control for tar'ring binaries including their runfiles.

TODO:
- Ensure we are reproducible, see https://reproducible-builds.org/docs/archives/
- Provide convenience for rules_pkg users to re-use or replace pkg_files trees
"""

load("@bazel_skylib//lib:types.bzl", "types")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//lib/private:tar.bzl", "tar_lib", _tar = "tar")

mtree_spec = rule(
    doc = "Create an mtree specification to map a directory hierarchy. See https://man.freebsd.org/cgi/man.cgi?mtree(8)",
    implementation = tar_lib.mtree_implementation,
    attrs = tar_lib.mtree_attrs,
)

tar_rule = _tar

def tar(name, mtree = "auto", **kwargs):
    """Wrapper macro around [`tar_rule`](#tar_rule).

    Options for mtree
    -----------------

    mtree provides the "specification" or manifest of a tar file.
    See https://man.freebsd.org/cgi/man.cgi?mtree(8)
    Because BSD tar doesn't have a flag to set modification times to a constant,
    we must always supply an mtree input to get reproducible builds.
    See https://reproducible-builds.org/docs/archives/ for more explanation.

    1. By default, mtree is "auto" which causes the macro to create an `mtree` rule.

    2. `mtree` may also be supplied as an array literal of lines, e.g.

    ```
    mtree =[
        "usr/bin uid=0 gid=0 mode=0755 type=dir",
        "usr/bin/ls uid=0 gid=0 mode=0755 time=0 type=file content={}/a".format(package_name()),
    ],
    ```

    For the format of a line, see "There are four types of lines in a specification" on the man page for BSD mtree,
    https://man.freebsd.org/cgi/man.cgi?mtree(8)

    3. `mtree` may be a label of a file containing the specification lines.

    Args:
        name: name of resulting `tar_rule`
        mtree: "auto", or an array of specification lines, or a label of a file that contains the lines.
        **kwargs: additional named parameters to pass to `tar_rule`
    """
    mtree_target = "_{}.mtree".format(name)
    if mtree == "auto":
        mtree_spec(
            name = mtree_target,
            srcs = kwargs["srcs"],
            out = "{}.txt".format(mtree_target),
        )
    elif types.is_list(mtree):
        write_file(
            name = mtree_target,
            out = "{}.txt".format(mtree_target),
            # Ensure there's a trailing newline, as bsdtar will ignore a last line without one
            content = mtree + [""],
            newline = "unix",
        )
    else:
        mtree_target = mtree

    tar_rule(
        name = name,
        mtree = mtree_target,
        **kwargs
    )
