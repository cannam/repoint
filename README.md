
Vext
====

A simple manager for third-party source code dependencies.

Vext is a program that manages a single directory in your repository,
containing checkouts of the external source code repositories that are
needed to build your own program.

You might think of it as an alternative to Mercurial subrepositories
or Git submodules, but with less magic and with equal support for both
Mercurial and Git.

You configure Vext with a list of libraries, their remote repository
locations, and any branch or tag information you want checkouts to
follow. This list is stored in your repository, and when you run the
Vext utility, it reviews the list and checks out the necessary code.

Vext has four limitations that distinguish it from all of the "proper"
package managers like npm or Maven:

 1. It only knows how to check out library code from hosted version
 control repositories (like Github or Bitbucket). There is no support
 for installing pre-packaged or pre-compiled dependencies. If it's not
 in a repository, or if cloning the repository would be too expensive,
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
 code is in.

Besides those limitations, it has one big advantage:

 1. It's equivalent to just checking out a bunch of repositories
 yourself, but with a neater interface. That makes it unintrusive and
 easy to understand, and suitable for situations where there isn't
 really a package manager that will do the job.

Vext was originally intended for use with projects written in C++ and
SML, having in the range of 1-20 library dependencies to a project.


Configuring Vext
----------------

### Setting up a project

The external libraries needed for a project are listed in a
`vext-project.json` file in the project's top-level working-copy
directory.

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
external-library directory in the project root; the name of this
directory (typically `ext`) is configured in `vext-project.json`. The
`ext` directory should normally be excluded from your project's own
version control, i.e. added to your `.hgignore`, `.gitignore` etc
file. The general expectation is that this directory contains only
third-party code, and one could safely delete the entire directory and
run Vext again to recreate it.

Libraries are listed in the `libs` object in the config file. Each
library has a key, which is the local name (a single directory or
relative path) it will be checked out to. Properties of the library
may include

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

Vext also creates a file called `vext-lock.json`, each time you update,
which stores the versions actually used in the current project
directory. This is referred to by the command `vext install`, which
installs exactly those versions. You can check this file into your
version control system if you want to enable other users to get
exactly the same revisions by running `vext install` themselves.


### Adding new service providers

You can cause a library to be checked out from any version control
system URL simply by specifying a `url` property for that library (in
addition to `vcs` to say which version control system to use) instead
of a `service` and its associated properties.

However, if you want to refer to a service repeatedly that is not one
of those hardcoded in the Vext program, you can add a `services`
property to the top-level object in `vext-project.json`. For example:

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

The above example adds a new service, local to this project, that can
be referred to as `soundsoftware` in library definitions. This service
supports Mercurial and Git.

The `anon` property describes how to construct a check out URL for
this service in the case where the current user has no account there,
and the `auth` property gives an alternative that can be used if the
user is known to have an account on the service (see "User
configuration" below).

The following variables (appearing in curly braces as in the example
above) will be expanded in `anon` and `auth` URLs when they are used
to construct a check out URL for a specific library:

 * `vcs` - the version control system being used, as found in the
   library's `vcs` property

 * `owner` - the owner of the repository, as found in the library's
   `owner` property

 * `repo` - the name of the repository, either the library name or (if
   present) the contents of the library's `repository` property

 * `account` - the user's login name for the service if known (see
   "User configuration" below)

 * `service` - the name of the service


### User configuration

You can provide some user configuration in a file called `.vext.json`
(with leading dot) in your home directory.

This file contains a JSON object which can have the following
properties:

 * `accounts` - account names for this user for known service
   providers, as an object mapping from service name to account name

 * `services` - global definitions of service providers, in the same
   format as described in "Adding new service providers"
   above. Definitions here will override those both hardcoded in Vext
   and listed in project specifications

If you specify an account name for a service in your `.vext.json`
file, Vext will assume that you have suitable keychain authentication
for that service and will check out libraries using the authenticated
versions of that service's URLs.


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

 * _Absent_: No repository has been checked out for the library yet

 * _Correct_: Library is the newest version available on the correct
   branch. If you run `vext status` instead `vext review`, this will
   appear as _Present_ instead of _Correct_, as the program can't be
   sure you have the latest version without using the network.

 * _Superseded_: Library exists and is on the correct branch, but
   there is a newer revision available.

 * _Wrong_: Library exists but is checked out on the wrong branch.

For pinned libraries:

 * _Absent_: No repository has been checked out for the library yet

 * _Correct_: Library is checked out at the pinned revision.

 * _Wrong_: Library is checked out at any other revision.

Also, both pinned and unpinned libraries can be shown with a local
status either "Clean" (not changed locally) or "Modified" (someone has
made a change to the local working copy for that library).


### Installing and updating libraries

Run `vext install` to check out all the configured libraries. If there
is a `vext-lock.json` file present, `vext install` will check out all
libraries listed in that file to the precise revisions recorded there.

Run `vext update` to update all the configured libraries according to
the `vext-project.json` specification, regardless of the existence of
any `vext-lock.json` file, and then write out a new `vext-lock.json`
containing the resulting state. Pinned libraries will be updated if
they are in Absent or Wrong state; unpinned libraries will always be
updated, which should have an effect only when they are in Absent,
Superseded, or Wrong state.


### Installing Vext itself

Vext consists of four files which are normally copied
(autotools-style) into the project root. These are `vext.sml` (the
actual program, as Standard ML source code) and `vext`, `vext.bat` and
`vext.ps1` (scripts which invoke the program using an SML
interpreter). To run the program you would usually type e.g. `./vext
update` rather than `vext update`.

Vext does require a Standard ML compiler or interpreter to be
installed. It supports Poly/ML, SML/NJ, or (on non-Windows platforms
only) MLton, and it's quite easy to install at least one of these on
every platform Vext is intended to support.

Vext has been tested on Linux, OSX, and Windows. CI tests currently
cover Linux and OSX with both Mercurial and Git repositories using all
three of the supported SML compilers.

Vext is a developer tool. Don't ask end-users of your software to use
it.


[![Build Status](https://travis-ci.org/cannam/vext.svg?branch=master)](https://travis-ci.org/cannam/vext)


to add:

 + archive command
 + note about not handling libraries having their own dependencies
 + ability to commit and/or push?
 + dry-run option (print commands)?
 + more tests: service definitions, weird lib paths, explicit URL etc
 + implant script
 
