
Vext
====

A simple manager for third-party source code dependencies.

Vext is a program that manages a directory of external source code
repositories that will be used during a build process. You configure
it with a list of libraries, their repository locations, and any
revision or tag information you want a checkout to be associated
with. This list is stored in your repository, and the Vext utility
checks out the necessary code with the appropriate (or latest)
revision. It's like using Mercurial subrepositories or Git submodules,
but without any version control system integration, and agnostic to
which system you use.

Vext has three limitations that distinguish it from "proper" package
managers:

 1. It only knows how to get things from version control
 repositories. There is no support for installing pre-packaged or
 pre-compiled dependencies. If it's not in a repository, or cloning
 the repository would be too expensive, then Vext won't help.

 2. It can only bring code in to a subdirectory of the local directory
 (vendoring). There is no per-user or per-system package install
 location. Every local working copy gets its own copy.

 3. It doesn't know how to build anything. It just brings in the
 source code, and your build process is assumed to know what to do
 with it. This also means it doesn't care what language the source
 code is in.

Libraries are listed in a .vex file in the top-level working-copy
directory, and Vext checks them out into subdirectories of a directory
called ext. The ext directory should normally be excluded from version
control (included in the .hgignore, .gitignore etc file).

Libraries are specified by name, version control system (hg, git etc),
repository hosting provider, and tag or revision ID. Vext knows about
some standard hosting providers and may know (through a configuration
in ~/.vext) the login names to use for ssh access to those providers.

A library may be listed as either pinned or unpinned. A pinned library
has a specific tag or revision ID associated with it, and once it has
been checked out at that tag, it won't be changed by Vext again unless
the specification for it changes. An unpinned library floats on a
branch and is potentially updated every time Vext is run.


Library status
==============

Run "vext check" to print statuses of all the configured libraries.

A pinned library can be _absent_, _present_, _superseded_, or _wrong_.

 * Absent: the library has not been checked out at all
 
 * Present: the library has been checked out at the specified tag and
   will not be changed; there is also no newer version available in the
   remote repository

 * Superseded: the library has been checked out at the specified tag
   and will not be changed, but the version checked out is not the
   newest version available in the remote repository

 * Wrong: the library has been checked out, but it is not at the
   specified tag (possibly because the library spec has changed since).

An unpinned library can be _absent_, _up-to-date_, or _out-of-date_.

 * Absent: the library has not been checked out at all

 * Up-to-date: the library has been checked out and there is no newer
   version available in the remote repository

 * Out-of-date: the library has been checked out, but the version
   checked out is not the newest version available in the remote
   repository

Additionally both pinned and unpinned libraries can be shown as
"modified", meaning they have been changed locally.


Updating
========

Run "vext update" to update all the configured libraries.

Pinned libraries will be updated if they are in Absent or Wrong state.

Unpinned libraries will always be updated, which should have an effect
when they are in Absent or Out-of-date state.

