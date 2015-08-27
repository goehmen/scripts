#!/bin/bash
# I hate to use bash, but I want to use arrays for stable/unstable URLs

set -e

# DEFAULTS
cli="cf"
rel=1
bindir="/usr/local/bin"
alt_url=""

usage="\
$0  Download and update a new version of a binary.

    Overwrites binaries that have the same semantic version (ie, new
    builds of the same release). Symlinks the binary name to the
    version requested (stable or edge). If the fresh binary is a new
    version, this script will symlink the currently installed version
    to [binary].old.

Options:
    -h                This help
    -c cli            Specify cf or ltc (or bosh) CLI (defaults to unstable release)
    -r stable|edge    Specify stable (release) or edge (unstable) release
    -p bindir         Specify the target directory to install the binary
                      (Defaults to: $bindir)
    -u url            Override binary URL
    -x                Debug mode
    -v                Print version
"

## Changelog
# Added a hint to give BOSH some love
# Added an -u option to override the URL used to d/l the cli
#   (Useful if you need a specific version rather than stable/unstable)
# Added a -v to print current version
# Clean up cf tar in /tmp, and empty /tmp file if curl fails
# Knows URIs for cf and ltc binaries
# Allows user to specify stable or edge
# Now saves previous semvers as .old, overwrites new builds of current semver
# Logic to make filenames include semver and symlink binary and binary.old
# Used $OSTYPE to auto-choose correct version # FIXME: Windows??
# Added getopt to process command line args, also usage help text
# Switched from wget to curl, since OSX doesn't ship with wget
# When downloading CF, identify source as "internal" (vs github)

version="0.0.4"

# Format is OS_CLI(Release Unstable)
darwin_CF=("https://cli.run.pivotal.io/stable?release=macosx64-binary&source=internal" "https://cli.run.pivotal.io/edge?arch=macosx64&source=internal")
# Assuming 64 bit versions only
linux_CF=("https://cli.run.pivotal.io/stable?release=linux64-binary&source=internal" "https://cli.run.pivotal.io/edge?arch=linux64&source=internal")
windows_CF=("https://cli.run.pivotal.io/stable?release=windows64-exe&source=internal" "https://cli.run.pivotal.io/edge?arch=windows64&source=internal")
#
darwin_LTC=("https://lattice.s3.amazonaws.com/releases/latest/darwin-amd64/ltc" "http://lattice.s3.amazonaws.com/nightly/lattice-bundle-latest-osx.zip")
# darwin_LTC=("https://lattice.s3.amazonaws.com/releases/latest/darwin-amd64/ltc" "https://lattice.s3.amazonaws.com/unstable/latest/darwin-amd64/ltc")
linux_LTC=("https://lattice.s3.amazonaws.com/releases/latest/linux-amd64/ltc" "http://lattice.s3.amazonaws.com/nightly/lattice-bundle-latest-linux.zip")
# linux_LTC=("https://lattice.s3.amazonaws.com/releases/latest/linux-amd64/ltc" "https://lattice.s3.amazonaws.com/unstable/latest/linux-amd64/ltc")
windows_LTC=("/bin/false" "/bin/false")
#
darwin_BOSH=("/bin/false" "/bin/false")
linux_BOSH=("/bin/false" "/bin/false")
windows_BOSH=("/bin/false" "/bin/false")

####

# Call like this: getver dir binary
getver () {
    if [ -e ${1}/$2 ]; then
        if [ ! -x ${1}/$2 -o ! -s ${1}/$2 ]; then
            echo "ERROR: Current version of ltc not executable. Fix that, then try again."
            exit 3
        fi
        
        current_ver=`${1}/$2 -v`
        version=$(echo $current_ver | sed -E 's/.*version (v*[^-[:space:]]+).*/\1/')
        # LTC final releases don't have a build number. CF still has a SHA.
        set +e; echo $current_ver | egrep -q '[^-]+-([^-]+)'
        if [ 0 -eq $? ]; then
            build=$(echo $current_ver | sed -E 's/[^-]+-([^-]+).*/\1/')
        else
            build="N/A"
        fi
        set -e
    else
        version="N/A"
    fi
}

download () {
    curl -sL $1 > $2-$$.bin
    if [ 0 -ne $? ]; then
        rm $2-$$.bin
        echo "Error downloading $2. Aborting."
        exit -1
    fi
}

# By the time relink() is called, $cur_version and $cur_build should
# already be set, and will bet set to "N/A" if no existing version or build
relink () {
    if [ "$cur_version"X != "N/AX" -a "$cur_version"X != "$new_version"X ] ; then
        # This is a new version, so replace any .old with the current binary
        if [ -e ${bindir}/${cli}.old -o -L ${bindir}/${cli}.old ] ; then
            # -L seems redundant, but -e does not work if .old points
            # to a file that DNE. Bug in /bin/test!?
            rm $bindir/${cli}.old;
        fi
        if [ ! -L ${bindir}/$cli ] ; then
            if [ "$cur_build"X != "N/AX" ]; then
                mv ${bindir}/$cli ${bindir}/${cli}-$cur_version-$cur_build
            else
                mv ${bindir}/$cli ${bindir}/${cli}-$cur_version
            fi
        fi
        if [ "$cur_build"X != "N/AX" ]; then
            ln -s $bindir/${cli}-$cur_version-$cur_build $bindir/${cli}.old
        else
            ln -s $bindir/${cli}-$cur_version $bindir/${cli}.old
        fi
        # Update old_version variables, which pointed to the previous .old version
        old_version=$cur_version
        old_build=$cur_build
    fi

    # If there's a pre-existing bin that's not a link, move it aside
    if [ -e ${bindir}/$cli -a ! -L ${bindir}/$cli ]; then
        if [ "$cur_build"X != "N/AX" ]; then
            mv ${bindir}/$cli ${bindir}/${cli}-$cur_version-$cur_build;
        else
            mv ${bindir}/$cli ${bindir}/${cli}-$cur_version
        fi
    fi

    # LTC ONLY - move the vagrant and terraform files into place.
    # They are always versioned, so no shuffling or re-linking required.
    if [ "ltc" == $cli ] ; then
        bundledir=lattice-bundle-*
        if [ ! -d ${bindir}/$bundledir ]; then
            mv lattice-bundle-* ${bindir}
        fi
    fi
    
    # Finally, if we haven't moved it aside already, then we're just
    # overwriting the current version with a new build, so remove the
    # current binary.
    if [ -e ${bindir}/$cli -a -L ${bindir}/$cli ] ; then rm ${bindir}/$cli; fi

    if [ 0 -eq $rel ]; then
        mv $cli ${bindir}/${cli}-$new_version
        ln -s ${bindir}/${cli}-$new_version ${bindir}/$cli
    else
        mv $cli ${bindir}/${cli}-$new_version-$new_build
        ln -s ${bindir}/${cli}-$new_version-$new_build ${bindir}/$cli
    fi
}

args=`getopt vxnhr:c:p:u: $*`; errcode=$?; set -- $args
if [ 0 -ne $errcode ]; then echo ; echo "$usage" ; exit $errcode ; fi

for i ; do
    case $i in
        -v)
            echo $version
            exit 0
            ;;
        -h)
            echo "$usage"
            exit 0 ;;
        -x)
            echo "Debug mode."
            set -x ; shift ;;
        -r)
            case "$2" in
                release|stable)
                    rel=0 ;;
                edge|unstable)
                    rel=1 ;;
                *)
                    echo "Error: release must be stable or edge."
                    exit 1
                    ;;
            esac
            shift; shift ;;
        -c)
            case "$2" in
                cf)
                    cli="cf" ;;
                ltc)
                    cli="ltc" ;;
                bosh)
                    echo "BOSH not implemented yet! (hint hint)"
                    exit 0 ;;
                *)
                    echo "Error: cli must be either cf or ltc."
                    exit 1
                    ;;
            esac
            shift ; shift ;;
        -p)
            bindir="$2"
            shift ; shift ;;
        -u)
            alt_url="$2" ;
            shift ; shift ;;
        --)
            shift ; break ;;
    esac
done    

if [ ! -e $bindir ]; then
    echo "ERROR: Target directory does not exist."
    exit 1
fi

if [ ! -z $alt_url ]; then
    cli_uri=$alt_url
else
    case $OSTYPE in
        darwin*)
            os="darwin"
            if [ "cf" == $cli ] ; then cli_uri=${darwin_CF[rel]}; fi
            if [ "ltc" == $cli ] ; then cli_uri=${darwin_LTC[rel]}; fi
            ;;
        linux*)
            os="linux"
            if [ "cf" == $cli ] ; then cli_uri=${linux_CF[rel]}; fi
            if [ "ltc" == $cli ] ; then cli_url=${linux_LTC[rel]}; fi
            ;;
        *)
            os="windows"
            if [ "cf" == $cli ] ; then cli_uri=${linux_CF[rel]}; fi
            if [ "ltc" == $cli ] ; then echo "Windows not supported."; exit 1; fi
    esac
fi

# Save off old version, if any
if [ -e $bindir/${cli}.old ] ; then
    getver $bindir ${cli}.old
    old_version=$version
    old_build=$build
else
    old_version="N/A"
    old_build="N/A"
fi
    
getver ${bindir} $cli
cur_version=$version
cur_build=$build

tmpdir="/tmp/${cli}-$$-$(date '+%m-%d-%Y_%H:%M:%S')"

mkdir $tmpdir
cd $tmpdir
echo "Downloading $cli_uri"
download $cli_uri $cli
# ltc and cf CLIs are distributed slightly differently
case $cli in
    cf)
        tar xf cf-$$.bin
        rm cf-$$.bin
        ;;
    ltc)
        echo "FIXME, using new .zip mode for latest; this will not work for stable until a release is complete"
        unzip -q ltc-$$.bin
        mv */ltc .
        ;;
    bosh)
        echo "BOSH not supported. How did you even get to this step, anyways?"
        exit -1
        ;;
esac
getver . $cli
new_version=$version
if [ 1 -eq $rel ]; then
    new_build=$build
fi

echo "Installing in $bindir"
relink
cd /tmp ; rm -r $tmpdir

# If we've updated the .old link, report what the new .old is.
if [ "$old_version"X != "N/AX" ]; then
    if [ "$old_build"X != "N/AX" ]; then
        echo "Old version ${old_version}-$old_build: ${bindir}/${cli}.old";
    else
        echo "Old version ${old_version}: ${bindir}/${cli}.old";
    fi
fi

echo "New version ${new_version}: ${bindir}/${cli}"
