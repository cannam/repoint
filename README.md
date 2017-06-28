
Vext
====

A simple manager for third-party source code dependencies.

Vext is a program that manages a single directory within your
project's working tree. This directory contains checkouts of the
external source code repositories that are needed to build your
program.

You might think of Vext as an alternative to Mercurial subrepositories
or Git submodules, but with less magic, fewer alarming failure cases,
and equal support for both Mercurial and Git.

You configure Vext with a list of libraries, their remote repository
locations, and any branch or tag information you want their checkouts
to conform to. This list is stored in your repository, and when you
run the Vext utility, it reviews the list and checks out the necessary
code.

With a normal installation of Vext within a project, running

```
$ ./vext install
```

should be sufficient to retrieve the necessary dependencies specified
for the project.

### Rationale

Vext was written as an alternative to Mercurial subrepositories for
cross-platform C++ projects with numerous external dependencies, so as
to manage them in a simple way without depending on a particular
version control system or host and without using a giant
mono-repository.

Vext has four limitations that distinguish it from "proper" package
managers like npm or Maven:

 1. It only knows how to check out library code in the form of
 complete version control repositories. There is no support for
 installing pre-packaged or pre-compiled dependencies. If it's not in
 a repository, or if cloning the repository would be too expensive,
 then Vext won't help.  (A corollary is that you should only use Vext
 in development trees that are themselves checked out from a hosted
 repo; don't distribute source releases or end-user packages that
 depend on it. If your code is distributed via a "proper" package
 manager itself, use that package manager for its dependencies too.)

 2. It puts all third-party libraries into a subdirectory of the
 project directory. There is no per-user or system-wide package
 installation location. Every local working copy gets its own copy.

 3. It doesn't do dependency tracking. If an external library has its
 own dependencies, you have to be aware of those and add them to the
 configuration yourself.

 4. It doesn't know how to build anything. It just brings in the
 source code, and your build process is assumed to know what to do
 with it. This also means it doesn't care what language the source
 code is in or what build tool you use.

Vext has one big advantage over "proper" package managers:

 1. It's equivalent to just checking out a bunch of repositories
 yourself, but with a neater interface. That makes it unintrusive,
 easy to understand, able to install libraries that aren't set up to
 be packages, and usable in other situations where there isn't a
 package manager ready to do the job.


Installing Vext
---------------

Vext consists of four files which can be copied autotools-style into
the project root. These are `vext`, `vext.sml`, `vext.bat` and
`vext.ps1`. The file `vext.sml` contains the actual program, while
`vext`, `vext.bat` and `vext.ps1` are platform-specific wrappers. In
this configuration, you should type `./vext` to run the Vext
tool. Alternatively the same files can be installed to the PATH like
any other executables.

The Vext distribution includes a shell script called `implant.sh`
which copies the four Vext files into whichever directory you run the
shell script from.

Vext requires a Standard ML compiler or interpreter to be available
when it is run. It supports [Poly/ML](http://polyml.org),
[SML/NJ](http://smlnj.org), or on non-Windows platforms,
[MLton](http://mlton.org). It is fairly easy to install at least one
of these on every platform Vext is intended to support.

Vext has been tested on Linux, macOS, and Windows. Integration tests
currently cover Linux and macOS with both Mercurial and Git
repositories using all three of the supported SML compilers.

Vext is a developer tool. Don't ask end-users of your software to use
it.

[![Build Status](https://travis-ci.org/cannam/vext.svg?branch=master)](https://travis-ci.org/cannam/vext)

Setting up a Vext project
-------------------------

List the external libraries needed for your project in a JSON file
called `vext-project.json` in your project's top-level directory.

A complete example of `vext-project.json`:

```
{
    "config": {
        "extdir": "ext"
    },
    "libs": {
        "vamp-plugin-sdk": {
            "vcs": "git",
            "service": "github",
            "owner": "c4dm"
        },
        "bqvec": {
            "vcs": "hg",
            "service": "bitbucket",
            "owner": "breakfastquay"
        }
    }
}
```

All libraries will be checked out into subdirectories of a single
external-library directory in the project root; the location of this
directory (typically `ext`) should be configured as the first thing in
`vext-project.json`. The directory in question should normally be
excluded from your project's own version control, i.e. added to your
`.hgignore`, `.gitignore` etc file. The usual expectation is that this
directory contains only third-party code, and that one could safely
delete the entire directory and run Vext again to recreate it.

Libraries are listed in the `libs` object in the config file. Each
library has a key, which is the local name (a single directory or
relative path) it will be checked out to within the external-library
directory. Properties of a library may include

 * `vcs` - The version control system to use. Must be one of the
   recognised set of names, currently `hg` (Mercurial) or `git`

 * `service` - The repository hosting service. Some services are
   built-in, but you can define further ones in a `services` section
   (see below)

 * `owner` - User name owning the repository at the provider

 * `repository` - Repository name at the provider, if it differs from
   the local library name

 * `url` - Complete URL to check out (as an alternative to specifying
   `service`, `owner`, etc)

 * `branch` - Branch to check out if not the default

 * `pin` - Specific revision id or tag to check out
 
You can also optionally have a config file `~/.vext.json` in which you
can configure things like login names to use for ssh access to
providers.

A library may be listed as either pinned (having a `pin` property) or
unpinned (lacking one). A pinned library has a specific tag or
revision ID associated with it, and once it has been checked out at
that tag, it won't be changed by Vext again unless the specification
for it changes. An unpinned library floats on a branch and is
potentially updated every time `vext update` is run.

Vext also creates a file called `vext-lock.json` each time you update
a project, which stores the versions actually used in the current
project directory. This is referred to by the command `vext install`,
which installs exactly those versions. You can check this file into
your version control system if you want to enable other users to get
exactly the same revisions by running `vext install` themselves.


Using the Vext tool
-------------------

### Reviewing library status

Run `vext review` to check and print statuses of all the configured
libraries. This won't change the local working copies, but it does
fetch any pending changes from remote repositories, so network access
is required.

Run `vext status` to do the same thing but without using the
network. That's much faster but can only tell you whether something is
in place for each library, not whether it's the newest thing
available.

The statuses that may be reported are:

For unpinned libraries:

 * __Absent__: No repository has been checked out for the library yet

 * __Correct__: Library is the newest version available on the correct
   branch. If you run `vext status` instead `vext review`, this will
   appear as __Present__ instead of __Correct__, as the program can't
   be sure you have the latest version without using the network.

 * __Superseded__: Library exists and is on the correct branch, but
   there is a newer revision available.

 * __Wrong__: Library exists but is checked out on the wrong branch.

For pinned libraries:

 * __Absent__: No repository has been checked out for the library yet

 * __Correct__: Library is checked out at the pinned revision.

 * __Wrong__: Library is checked out at any other revision.

Also, both pinned and unpinned libraries can be shown with a local
status either "Clean" (not changed locally) or "Modified" (someone has
made a change to the local working copy for that library).

### Installing and updating libraries

Run `vext install` to install, i.e. to check out locally, all the
configured libraries. If there is a `vext-lock.json` file present,
`vext install` will check out all libraries listed in that file to the
precise revisions recorded there.

Run `vext update` to update all the configured libraries according to
the `vext-project.json` specification, regardless of the existence of
any `vext-lock.json` file, and then write out a new `vext-lock.json`
containing the resulting state. Pinned libraries will be updated if
they are in Absent or Wrong state; unpinned libraries will always be
updated, which should have an effect only when they are in Absent,
Superseded, or Wrong state.


Further configuration
---------------------

### Adding new service providers

You can cause a library to be checked out from any URL, even one that
is not from a known hosting service, simply by specifying a `url`
property for that library.

Alternatively, if you want to refer to a service repeatedly that is
not one of those hardcoded in the Vext program, you can add a
`services` property to the top-level object in
`vext-project.json`. For example:

```
{
    "config": {
        "extdir": "ext"
    },
    "services": {
        "soundsoftware": {
            "vcs": ["hg", "git"],
            "anon": "https://code.soundsoftware.ac.uk/{vcs}/{repo}",
            "auth": "https://{account}@code.soundsoftware.ac.uk/{vcs}/{repo}"
        }
    },
    "libs": {
        [etc]
```

The above example defines a new service, local to this project, that
can be referred to as `soundsoftware` in library definitions. This
service is declared to support Mercurial and Git.

The `anon` property describes how to construct a checkout URL for this
service in the case where the user has no login account there, and the
`auth` property gives an alternative that can be used if the user is
known to have an account on the service (see "User configuration"
below).

The following variables will be expanded if they appear within curly
braces in `anon` and `auth` URLs, when constructing a checkout URL for
a specific library:

 * `vcs` - the version control system being used, as found in the
   library's `vcs` property

 * `owner` - the owner of the repository, as found in the library's
   `owner` property

 * `repo` - the name of the repository, either the library name or (if
   present) the contents of the library's `repository` property

 * `account` - the user's login name for the service if known (see
   "Per-user configuration" below)

 * `service` - the name of the service

### Per-user configuration

You can provide some user configuration in a file called `.vext.json`
(with leading dot) in your home directory.

This file contains a JSON object which can have the following
properties:

 * `accounts` - account names for this user for known service
   providers, in the form of an object mapping from service name to
   account name

 * `services` - global definitions of service providers, in the same
   format as described in "Adding new service providers"
   above. Definitions here will override both those hardcoded in Vext
   and those listed in project files.

If you specify an account name for a service in your `.vext.json`
file, Vext will assume that you have suitable keychain authentication
set up for that service and will check out libraries using the
authenticated versions of that service's URLs.


### Developer todo / to-document notes

 + archive command
 + dry-run option (print commands)?
 + more tests: service definitions, weird lib paths, explicit URL etc
 
