
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

