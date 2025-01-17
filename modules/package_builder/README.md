Introduction
============

A module used to populate a Debian/Ubuntu package building environment. Meant to
be used in the Wikimedia environment but could be adapted for other
environments as well.

Setting it up
=============

Include the package\_builder class in your machine. That can be done with whatever
ENC you have puppet working with but in Wikimedia Labs you should create a
puppet group, then add the class in the puppet group and just configure your VM
with that class

After puppet is done you will have a number of pristine cowbuilder environments. Those
would be:

 * buster-amd64
 * bullseye-amd64
 * sid-amd64

Building packages
=================

You just either download a ready package:

    dget http://http.debian.net/debian/pool/main/d/dh-virtualenv/dh-virtualenv_0.10-1.dsc
    export DIST=bullseye
    sudo -E cowbuilder --build dh-virtualenv_0.10-1.dsc

or if you are developing a package and are in the package directory:

    DIST=bullseye pdebuild

Feel free to change bullseye for the distribution of your choice from the ones above

Architectures
=============

ARCH=amd64, or ARCH=i386 is supported if you feel like building for
different architecture versions. There is no support for other architectures

Debugging
=========

By default, if the build fails, a hook is executed, providing the user with a
shell allowing them to debug the build further. If that's not desired, there's a
variable that can be defined to avoid that behavior. Example:

    SHELL_ON_FAILURE=no pdebuild

If you reach the conclusion that your build fails because of some effort to write
to HOME, and fixing the software to not do that is unfeasible, then you can set

    BUILD\_HOME = /build

in .pbuilderrc or /etc/pbuilderrc

Using built packages as dependencies
====================================

By default, cowbuilder will always prefer upstream packages to packages
you have built. If you have built a new version of a dependency, you typically
want to use that version rather than the one provided by upstream. To force
cowbuilder to use packages in the result directory, use:

    APT_USE_BUILT=yes sudo -E cowbuilder --build dh-virtualenv_0.10-1.dsc

Wikimedia repos
===============

Aside from sid, the rest of the distributions allow for satisfying build time
dependencies via the Wikimedia repos.

To use packages from the Wikimedia repos to satisfy build dependencies during
building you can use WIKIMEDIA=yes. There is also the approach of appending
-wikimedia to the DIST variable and pbuilder will do what you want.

Examples:

    DIST=bullseye-wikimedia pdebuild
    WIKIMEDIA=yes DIST=bullseye pdebuild

The commands above are equivalent and will both build a package for the
stretch distribution using the Wikimedia apt repository.

Backports repos
===============

Packages from the Debian backports repositories can be used to satisfy
dependencies as well. To use the backports repository for the distribution
selected (e.g. stretch-backports), use either of:

    DIST=bullseye BACKPORTS=yes pdebuild
    DIST=bullseye-backports pdebuild

Archived suites
===============

Backports is only available for the regular lifetime of a Debian release, not
during the LTS stage. After that packages should ideally be rebuilt using
internally built components. If this isn't possible for some reason, the
ARCHIVE\_BACKPORTS hook can be used to pull in the backports repository from
archive.debian.org.

    DIST=buster ARCHIVE\_BACKPORTS=yes pdebuild

Combining Wikimedia and Backports repos
=======================================

Set both WIKIMEDIA and BACKPORTS:

    DIST=bullseye BACKPORTS=yes WIKIMEDIA=yes pdebuild

When using a distribution suffix, the other repo must be enabled via an
environment variable. The following examples are equivalent:

  DIST=bullseye-backports WIKIMEDIA=yes pdebuild
  DIST=bullseye-wikimedia BACKPORTS=yes pdebuild

git-buildpackage
================

git-pbuilder can be used by git-buildpackage to leverage all of the above but
instead of DIST and ARCH you need to use --git-dist=$DIST and --git-arch=$ARCH.

    WIKIMEDIA=yes gbp buildpackage -sa -us -uc --git-pbuilder --git-no-pbuilder-autoconf --git-dist=bullseye

-sa is being used to enforce the original tarball to be included in the
.changes file which is a requirement for Wikimedia reprepro.

The --git-no-pbuilder-autoconf/GIT\_PBUILDER\_AUTOCONF=no tells git-pbuilder to
forego all attempts to discover the base path, tarball, or configuration file
to set up the pbuilder options but rather instead rely on the settings in
.pbuilderrc

You can make it a default by editing your ~/.gbp.conf:

    [buildpackage]
    pbuilder = True
    pbuilder-autoconf = False
    dist = buster

Without "dist = buster" gbp will build for sid by default.

Results
=======

The resulting deb files should be in /var/cache/pbuilder/result/${DIST}-${ARCH} like:

    /var/cache/pbuilder/result/bullseye-amd64/

Notes
=====

If you are getting confused over the naming of pbuilder/cowbuilder, here's some
info to help you. pbuilder is the actual base software, cowbuilder is an
extension to allow pbuilder to use COW (copy on write) instead of slow .tar.gz
base files. For all intents and purposes this should be transparent to you as
cowbuilder is the default pbuilder builder.

Networking
==========

cowbuilder/pbuilder block networking using Linux namespaces. Technically speaking an
*unshare* is done in those environments, but the effect is that you can expect
networking to not work.

If your package requires internet access to build successfully, it will not
work.

First, try to fix the package. Packages in general should not require internet
access to be built for a variety of reasons which will not be explained here.

If that is impossible/undesirable, then set

    USENETWORK=yes

in /etc/pbuilderrc or ~/.pbuilderrc can be used to override that behaviour.
Make sure that the building host has internet access though, or else your change
will not be useful
