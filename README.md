
Repoint
=======

A simple manager for third-party source code dependencies.

Repoint is a program that manages a single directory within your
project's working tree. This directory contains checkouts of the
external source code repositories that are needed to build your
program.

You might think of Repoint as an alternative to Mercurial subrepositories
or Git submodules, but with less magic, fewer alarming failure cases,
and support for libraries hosted using Mercurial, Git, or Subversion,
regardless of what version control system is used for your main project.

You configure Repoint with a list of libraries, their remote repository
locations, and any branch or tag information you want their checkouts
to conform to. This list is stored in your repository, and when you
run the Repoint utility, it reviews the list and checks out the necessary
code.

With a normal installation of Repoint within a project, running

```
$ ./repoint install
```

should be sufficient to retrieve the necessary dependencies specified
for the project.

### Rationale

Repoint was written as an alternative to Mercurial subrepositories for
cross-platform C++ projects with numerous external dependencies, so as
to manage them in a simple way without depending on a particular
version control system and without using a giant mono-repository.

Repoint has four limitations that distinguish it from "proper" package
managers like npm or Maven:

 1. It only knows how to check out library code in the form of
 complete version control repositories. There is no support for
 installing pre-packaged or pre-compiled dependencies. If it's not in
 a repository, or if cloning the repository would be too expensive,
 then Repoint won't help.  (A corollary is that you should only use Repoint
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

In turn it has one big advantage over "proper" package managers:

 1. It is equivalent to cloning a bunch of repositories yourself, but
 with a neater interface. That makes it unintrusive, easy to
 understand, able to install libraries that aren't set up to be
 packages, and usable in other situations where there isn't a package
 manager ready to do the job.


Installing Repoint
------------------

Repoint consists of four files which can be copied autotools-style into
the project root. These are `repoint`, `repoint.sml`, `repoint.bat` and
`repoint.ps1`. The file `repoint.sml` contains the actual program, while
`repoint`, `repoint.bat` and `repoint.ps1` are platform-specific wrappers. In
this configuration, you should type `./repoint` to run the Repoint tool
regardless of platform. Alternatively the same files can be installed
to the PATH like any other executables.

The Repoint distribution also includes a Bash script called `implant.sh`
which copies the four Repoint files into whichever directory you run the
shell script from.

### Platform support

Repoint has been tested on Linux, macOS, and Windows. It has
continuous-integration testing across all three platforms, though it
is much less thoroughly tested on Windows than the other two
platforms.

Repoint requires a Standard ML compiler to be available when it is
run. It supports [Poly/ML](http://polyml.org),
[SML/NJ](http://smlnj.org), or, on non-Windows platforms only,
[MLton](http://mlton.org) and [MLKit](http://www.elsman.com/mlkit/).
It is fairly easy to install at least one
of these on every platform Repoint is intended to support.

Repoint is a developer tool. Don't ask end-users of your software to use
it.

* Linux and macOS CI build: [![Build Status](https://travis-ci.org/cannam/repoint.svg?branch=master)](https://travis-ci.org/cannam/repoint)
* Windows CI build: [![Build status](https://ci.appveyor.com/api/projects/status/y7x6sht8bmfvld1k?svg=true)](https://ci.appveyor.com/project/cannam/repoint)

Setting up a Repoint project
----------------------------

List the external libraries needed for your project in a JSON file
called `repoint-project.json` in your project's top-level directory.

A complete example of `repoint-project.json`:

```
{
    "config": {
        "extdir": "ext"
    },
    "libraries": {
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
`repoint-project.json`. The directory in question should normally be
excluded from your project's own version control, i.e. added to your
`.hgignore`, `.gitignore` etc file. The usual expectation is that this
directory contains only third-party code, and that one could safely
delete the entire directory and run Repoint again to recreate it.

Libraries are listed in the `libraries` object in the config
file. Each library has a key, which is the local name (a single
directory or relative path) it will be checked out to within the
external-library directory. Properties of a library may include

 * `vcs` - The version control system to use. Must be one of the
   recognised set of names, currently `git`, `hg` (Mercurial), or
   `svn` (Subversion).

 * `service` - The repository hosting service. Some services are
   built-in, but you can define further ones in a `services` section
   (see "Further configuration" below).

 * `owner` - User or project name of the owner of the repository on
   the hosting service.

 * `repository` - Repository name at the provider, if it differs from
   the local library name.

 * `url` - Complete URL to check out, as an alternative to specifying
   the `service`, `owner`, etc.

 * `branch` - Branch to check out if not the default.

 * `pin` - Specific revision id or tag to check out if not always the
   latest.
 
A library that has a `pin` property is pinned to a specific tag or
revision ID, and once it has been checked out at that tag or ID, it
won't be changed by Repoint again unless the specification for it
changes. An unpinned library floats on a branch and is potentially
updated every time `repoint update` is run.

Repoint creates a file called `repoint-lock.json` each time you update a
project, which stores the versions actually used in the current
project directory. This is then used by the command `repoint install`,
which installs exactly the versions listed in the lock file. You can
check this file into your version control system to ensure that other
users get the same revisions when running `repoint install` themselves.

See "Advanced stuff" below for more per-project and per-user
configuration possibilities.


Using the Repoint tool
----------------------

### Reviewing library status

Run `repoint review` to check and print statuses of all the configured
libraries. This won't change the local working copies, but it does
fetch any pending changes from remote repositories, so network access
is required.

Run `repoint status` to do the same thing but without using the
network. That's much faster but it can only tell you whether a library
is present locally at all, not necessarily whether it's the newest
version.

The statuses that may be reported by `review` or `status` are:

For unpinned libraries:

 * __Absent__: No repository has been checked out for the library yet

 * __Correct__: Library is the newest version available on the correct
   branch. If you run `repoint status` instead `repoint review`, this will
   appear as __Present__ instead of __Correct__, as the program can't
   be sure you have the latest version without using the network.

 * __Superseded__: Library exists and is on the correct branch, but
   there is a newer revision available.

 * __Wrong__: Library exists but is checked out on the wrong branch.

For pinned libraries:

 * __Absent__: No repository has been checked out for the library yet

 * __Correct__: Library is checked out at the pinned revision.

 * __Wrong__: Library is checked out at any other revision.

A local status will also be shown:

 * __Clean__: The library has no un-committed local modifications.

 * __Modified__: The library has local modifications that have not
   been committed.

 * __Differs from Lock__: The library is checked out at a version that
   differs from the one listed in the `repoint-lock.json` file. Either
   the lock file needs updating (by `repoint update` or `repoint lock`) or
   the wrong revision is checked out and this should be fixed (by
   `repoint install`).

Note that at present Repoint cannot always report local modifications
that have been committed but not pushed, although the presence of such
a commit is one possible cause of the __Differs from Lock__ status.

### Installing and updating libraries

Run `repoint install` to install, i.e. to check out locally, all of
the configured libraries.

If there is a `repoint-lock.json` file present, `repoint install` will
check out all libraries listed in that file to the precise revisions
recorded there. Otherwise it will follow any branch and/or pinned id
specified in the project file.

Note that `repoint install` always follows the lock file if present,
even if it contradicts the project file.

Run `repoint update` to update all the configured libraries according to
the `repoint-project.json` specification, and then write out a new
`repoint-lock.json` containing the resulting state.

Note that `repoint update` always ignores the existing contents of the
lock file, but it does take into account the branch and pin
specifications in the project file. Pinned libraries will be updated
to the pinned version if they are in Absent or Wrong state; unpinned
libraries will always be updated, which should have an effect only
when they are in Absent, Superseded, or Wrong state.

Run `repoint lock` to rewrite `repoint-lock.json` according to the actual
state of the installed libraries. (As `repoint update` does, but without
changing any of the library code.)

### Creating an archive file

To pack up a project and all its configured libraries into an archive
file, run `repoint archive` with the target filename as argument,
e.g. `repoint archive /home/user/myproject-v1.0.tar.gz`. This works by
checking out a temporary clean copy of the project's own repository,
so it requires that the project itself is version-controlled using one
of the same version-control systems as Repoint supports for libraries.

Repoint expects the archive target filename to have one of a small set of
recognised suffixes: .tar, .tar.gz, .tar.bz2, .tar.xz, and it requires
that GNU tar or a compatible program be available in the current
PATH. (This is unlikely to be straightforward on Windows.) Zip
archives are not yet supported. You can explicitly exclude some files
from the archive by adding one or more options of the form `--exclude
<path>` after the target filename.


Advanced stuff
--------------

### Changing the upstream origin of a library

If the upstream repository URL for a library changes -- e.g. if the
library moves to a different provider, or if you want to pick up a
different fork of it -- you can change its details in
`repoint-project.json` to reflect the new location, and that location
will be used for all subsequent Repoint operations.

This should work seamlessly for all of the supported version control
systems, so long as the new location has the same root commit as
before (i.e. it is not an unrelated repository) and so long as it uses
the same version control system.

If you want to switch a library to check out from a repository
unrelated to its current one, or switch it to a different version
control system, then for the moment you will have to remove any
existing checkout of that library by hand first.

### Re-running Repoint from a build system when something changes

When a Repoint update or install process completes, Repoint touches an
(empty) checkpoint file called `.repoint.point` in the project root
directory. You can use this to check whether Repoint should be run: if
`.repoint.point` is missing, or is older than either
`repoint-project.json` or `repoint-lock.json`, then `repoint install`
should be run before the build can complete.

A Makefile or other build system can include a rule to check this and
run `repoint install` automatically, with some caveats:

 * If the build system reads recursive build files or dependencies
   from the external library directories, then the build system will
   itself need to be re-run after Repoint has installed the libraries;

 * Repoint is a developer tool, not an end-user tool: if your code is
   intended to be built by people who are not active developers of it,
   then it should be packaged in a way that does not require running
   Repoint to build it (for example using `repoint archive`).

Repoint supports a `--directory` option to tell it which directory is
the project root, for use when being invoked from a build script in a
different directory, such as in a shadow-build configuration.

### Limitations when checking libraries out using Subversion

Libraries checked out from a Subversion repository are in basic cases
handled identically to those checked out from Git or Mercurial. But
there are some limitations specific to Subversion:

 * Repoint is not aware of the Subversion conventions for branching or
   tagging. Branches and tags must be specified by changing the
   checkout URL.

 * The lack of local history in a Subversion repo has an effect on the
   information that can be reported by Repoint. For example, `repoint
   status` can never report Superseded for a Subversion checkout.

 * If you modify and commit a Subversion repository, remember that you
   must subsequently run `svn update` in it before it has the right
   local revision ID. You may get confusing results from `repoint`
   commands if you forget to do this.

### Adding new service providers

You can cause a library to be checked out from any URL, even one that
is not from a known hosting service, simply by specifying a `url`
property for that library.

Alternatively, if you want to refer to a service repeatedly that is
not one of those hardcoded in the Repoint program, you can add a
`services` property to the top-level object in
`repoint-project.json`. For example:

```
{
    "config": {
        "extdir": "ext"
    },
    "services": {
        "soundsoftware": {
            "vcs": ["hg", "git"],
            "anonymous": "https://code.soundsoftware.ac.uk/{vcs}/{repository}",
            "authenticated": "https://{account}@code.soundsoftware.ac.uk/{vcs}/{repository}"
        }
    },
    "libraries": {
        [etc]
```

The above example defines a new service, local to this project, that
can be referred to as `soundsoftware` in library definitions. This
service is declared to support Mercurial and Git.

The `anonymous` property describes how to construct a checkout URL for
this service in the case where the user has no login account there,
and the `authenticated` property gives an alternative that can be used
if the user is known to have an account on the service (see "User
configuration" below).

The following variables will be expanded if they appear within curly
braces in `anonymous` and `authenticated` URLs, when constructing a
checkout URL for a specific library:

 * `vcs` - the version control system being used, as found in the
   library's `vcs` property.

 * `owner` - the owner of the repository, as found in the library's
   `owner` property.

 * `repository` - the name of the repository, either the library name
   or (if present) the contents of the library's `repository`
   property.

 * `account` - the user's login name for the service if known (see
   "Per-user configuration" below).

 * `service` - the name of the service.

### Per-user configuration

You can provide some user configuration in a file called `.repoint.json`
(with leading dot) in your home directory.

This file contains a JSON object which can have the following
properties:

 * `accounts` - account names for this user for known service
   providers, in the form of an object mapping from service name to
   account name.

 * `services` - global definitions of service providers, in the same
   format as described in "Adding new service providers"
   above. Definitions here will override both those hardcoded in Repoint
   and those listed in project files.

As an example of `.repoint.json` with an `accounts` property:
```
{
    "accounts": {
        "github": "cannam",
        "bitbucket": "cannam"
    }
}
```

Repoint may use a different checkout URL with services on which you have
declared an account name, in order to take advantage of the
possibility of using an authenticated protocol that can be pushed to
using keychain authentication. For example, providing an account name
may cause Repoint to switch to an ssh URL in place of a default https
URL.


Author and licence
------------------

Repoint was written by Chris Cannam, copyright 2017-2018 Chris Cannam,
Particular Programs Ltd, and Queen Mary University of London. It is
free software provided under an MIT-style licence. See the file
COPYING for details.

