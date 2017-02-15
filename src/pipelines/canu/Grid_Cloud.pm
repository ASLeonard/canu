
###############################################################################
 #
 #  This file is part of canu, a software program that assembles whole-genome
 #  sequencing reads into contigs.
 #
 #  This software is based on:
 #    'Celera Assembler' (http://wgs-assembler.sourceforge.net)
 #    the 'kmer package' (http://kmer.sourceforge.net)
 #  both originally distributed by Applera Corporation under the GNU General
 #  Public License, version 2.
 #
 #  Canu branched from Celera Assembler at its revision 4587.
 #  Canu branched from the kmer project at its revision 1994.
 #
 #  Modifications by:
 #
 #    Brian P. Walenz beginning on 2017-JAN-17
 #      are a 'United States Government Work', and
 #      are released in the public domain
 #
 #  File 'README.licenses' in the root directory of this distribution contains
 #  full conditions and disclaimers for each license.
 ##

package canu::Grid_Cloud;

require Exporter;

@ISA    = qw(Exporter);
@EXPORT = qw(setWorkDirectory
             setWorkDirectoryShellCode
             fileExists
             fileExistsShellCode
             fetchFile
             fetchFileShellCode
             stashFile
             stashFileShellCode
             fetchStore
             fetchStoreShellCode
             stashStore
             stashStoreShellCode);

use strict;

use File::Path qw(make_path);
use File::Basename;

use Cwd qw(getcwd);

use canu::Defaults;
use canu::Grid;
use canu::Execution;


#
#  If running on a cloud system, shell scripts are started in some random location.
#  setWorkDirectory() will create the directory the script is supposed to run in (e.b.,
#  correction/0-mercounts) and move into it.  This will keep the scripts compatible with the way
#  they are run from within canu.pl.
#
#sub setWorkDirectory          ()
#sub setWorkDirectoryShellCode (workDirectory)
#
#
#  fileExists() returns true if the file exists on disk or in the object store.  It does not fetch
#  the file.  It returns undef if the file doesn't exist.  The second argument to
#  fileExistsShellCode() is an optional indent level (a whitespace string).
#
#sub fileExists          ($)
#sub fileExistsShellCode ($@)
#
#
#
#  fetchFile() and stashFile() both expect to be called from the assembly root directory, and have
#  the path to the file, e.g., "correction/0-mercounts/whatever.histogram".
#
#  The shellCode versions expect the same, but need the path from the assembly root to the location
#  the shell script is running split.  A meryl script would give "correction/0-mercounts" for the
#  first arg, and could give "some/directory/file" for the file.
#
#sub fetchFile          ($base/$stage/$file)
#sub fetchFileShellCode ($base/$stage, $file, $indent)
#
#
#sub stashFile          ($base/$stage/$file)
#sub stashFileShellCode ($base/$stage, $file, $indent)
#
#
#  Given $base/$asm.gkpStore, fetch or stash it.
#
#  The non-shell versions are assumed to be running in the assembly directory, that is, where
#  $base/$asm.gkpStore would exist naturally.  This is consistent with canu.pl - it runs in the
#  assembly directory, and then chdir to subdirectories to run binaries.
#
#  The shell versions usually run within a subdirectory (e.g., in correction/0-mercounts).  They
#  need to know this location, so they can go up to the assembly directory to fetch and unpack the
#  store.  After fetching, they chdir back to the subdirectory.
#
#sub fetchStore          (base/storeName)
#sub stashStore          (base/storeName)
#sub fetchStoreShellCode (base/storeName, base/3-compute, indentLevel)



#  Convert a/path/to/file to ../../../..
sub pathToDots ($) {
    return(join("/", map("..", (1..scalar(split '/', $_[0])))));
}

#  True if we're using an object store.
sub isOS () {
    return(getGlobal("objectStore"));
}



sub setWorkDirectory () {

    if    ((isOS() eq "TEST") && (defined($ENV{"JOB_ID"}))) {
        my $jid = $ENV{'JOB_ID'};
        my $tid = $ENV{'SGE_TASK_ID'};

        make_path("/assembly/COMPUTE/job-$jid-$tid");
        chdir    ("/assembly/COMPUTE/job-$jid-$tid");
    }

    elsif (isOS() eq "DNANEXUS") {
    }

    elsif (getGlobal("gridEngine") eq "PBSPRO") {
        chdir($ENV{"PBS_O_WORKDIR"})   if (exists($ENV{"PBS_O_WORKDIR"}));
    }
}



sub setWorkDirectoryShellCode ($) {
    my $path = shift @_;
    my $code = "";

    if    (isOS() eq "TEST") {
        $code .= "if [ z\$SGE_TASK_ID != z ] ; then\n";
        $code .= "  jid=\$JOB_ID\n";
        $code .= "  tid=\$SGE_TASK_ID\n";
        $code .= "  mkdir -p /assembly/COMPUTE/job-\$jid-\$tid/$path\n";
        $code .= "  cd       /assembly/COMPUTE/job-\$jid-\$tid/$path\n";
        $code .= "  echo IN  /assembly/COMPUTE/job-\$jid-\$tid/$path\n";
        $code .= "fi\n";
    }
    elsif (isOS() eq "DNANEXUS") {
    }
    elsif (getGlobal("gridEngine") eq "PBSPRO") {
        $code .= "if [ z\$PBS_O_WORKDIR != z ] ; then\n";
        $code .= "  cd \$PBS_O_WORKDIR\n";
        $code .= "fi\n";
    }

    return($code);
}



sub fileExists ($) {
    my $file   = shift @_;
    my $exists = "";
    my $client = getGlobal("objectStoreClient");

    return(1)   if (-e $file);           #  If file exists, it exists.

    if    (isOS() eq "TEST") {
        $exists = `$client describe --name $file`;
    }
    elsif (isOS() eq "DNANEXUS") {
    }
    else {
        $exists = "";
    }

    $exists =~ s/^\s+//;
    $exists =~ s/\s+$//;

    return(($exists ne "") ? 1 : undef);
}



sub fileExistsShellCode ($@) {
    my $file   = shift @_;
    my $indent = shift @_;
    my $code   = "";
    my $client = getGlobal("objectStoreClient");

    if    (isOS() eq "TEST") {
        $code .= "${indent}if [ ! -e $file ] ; then\n";
        $code .= "${indent}  exists=`$client describe --name $file`\n";
        $code .= "${indent}fi\n";
        $code .= "${indent}if [ -e $file -o x\$exists != x ] ; then\n";
    }
    elsif (isOS() eq "DNANEXUS") {
    }
    else {
        $code .= "${indent}if [ -e $file ]; then\n";
    }

    return($code);
}



sub fetchFile ($) {
    my $file   = shift @_;
    my $client = getGlobal("objectStoreClient");

    return   if (-e $file);   #  If it exists, we don't need to fetch it.

    if    (isOS() eq "TEST") {
        make_path(dirname($file));
        runCommandSilently(".", "$client download --output $file $file", 1);
    }
    elsif (isOS() eq "DNANEXUS") {
    }
    else {
    }
}

sub fetchFileShellCode ($$$) {
    my $path   = shift @_;
    my $dots   = pathToDots($path);
    my $file   = shift @_;
    my $indent = shift @_;
    my $code   = "";
    my $client = getGlobal("objectStoreClient");

    #  We definitely need to be able to fetch files from places that are
    #  parallel to us, e.g., from 0-mercounts when we're in 1-overlapper.
    #
    #  To get a file, we first go up to the assembly root, then check if the
    #  file exists, and fetch it if not.
    #
    #  The call needs to be something like:
    #    stashFileShellCode("correction/0-mercounts", "whatever", "");

    if    (isOS() eq "TEST") {
        $code .= "${indent}if [ ! -e $dots/$path/$file ] ; then\n";
        $code .= "${indent}  mkdir -p $dots/$path\n";
        $code .= "${indent}  cd       $dots/$path\n";
        $code .= "${indent}  $client download --output $file $path/$file\n";
        $code .= "${indent}  cd -\n";
        $code .= "${indent}fi\n";
    }
    elsif (isOS() eq "DNANEXUS") {
    }
    else {
    }

    return($code);
}



sub stashFile ($) {
    my $file   = shift @_;
    my $client = getGlobal("objectStoreClient");

    return   if (! -e $file);

    if    (isOS() eq "TEST") {
        runCommandSilently(".", "$client upload --path $file $file", 1);
    }
    elsif (isOS() eq "DNANEXUS") {
    }
    else {
    }

}

sub stashFileShellCode ($$$) {
    my $path   = shift @_;
    my $dots   = pathToDots($path);
    my $file   = shift @_;
    my $indent = shift @_;
    my $code   = "";
    my $client = getGlobal("objectStoreClient");

    #  Just like for fetching, we allow stashing files from parallel
    #  directories (even though that should never happen).

    if    (isOS() eq "TEST") {
        $code .= "${indent}if [ -e $dots/$path/$file ] ; then\n";
        $code .= "${indent}  cd $dots/$path\n";
        $code .= "${indent}  $client upload --path $path/$file $file\n";
        $code .= "${indent}  cd -\n";
        $code .= "${indent}fi\n";
    }
    elsif (isOS() eq "DNANEXUS") {
    }
    else {
    }

    return($code);
}



sub fetchStore ($) {
    my $store  = shift @_;                           #  correction/asm.gkpStore
    my $client = getGlobal("objectStoreClient");

    return   if (-e "$store/info");                  #  Store exists on disk
    return   if (! fileExists("$store.tar"));        #  Store doesn't exist in object store

    if    (isOS() eq "TEST") {
        runCommandSilently(".", "$client download --output - $store.tar | tar -xf -", 1);
    }
    elsif (isOS() eq "DNANEXUS") {
    }
    else {
    }
}



sub stashStore ($) {
    my $store  = shift @_;                         #  correction/asm.gkpStore
    my $client = getGlobal("objectStoreClient");

    return   if (! -e "$store/info");              #  Store doesn't exist on disk

    if    (isOS() eq "TEST") {
        runCommandSilently(".", "tar -cf - $store | $client upload --path $store.tar -", 1);
    }
    elsif (isOS() eq "DNANEXUS") {
    }
    else {
    }
}



sub fetchStoreShellCode ($$@) {
    my $store  = shift @_;           #  correction/asm.gkpStore - store we're trying to get
    my $root   = shift @_;           #  correction/1-overlapper - place the script is running in
    my $indent = shift @_;           #
    my $base   = dirname($store);    #  correction
    my $basep  = pathToDots($root);  #  ../..
    my $name   = basename($store);   #             asm.gkpStore
    my $code;
    my $client = getGlobal("objectStoreClient");

    if    (isOS() eq "TEST") {
        $code .= "${indent}if [ ! -e $basep/$store/info ] ; then\n";
        $code .= "${indent}  echo Fetching $store\n";
        $code .= "${indent}  $client download --output - $store.tar | tar -C $basep -xf -\n";
        $code .= "${indent}fi\n";
    }
    elsif (isOS() eq "DNANEXUS") {
    }
    else {
    }

    return($code);
}



sub stashStoreShellCode ($$@) {
    my $store  = shift @_;           #  correction/asm.gkpStore - store we're trying to get
    my $root   = shift @_;           #  correction/1-overlapper - place the script is running in
    my $indent = shift @_;           #
    my $base   = dirname($store);    #  correction
    my $basep  = pathToDots($root);  #  ../..
    my $name   = basename($store);   #             asm.gkpStore
    my $code;
    my $client = getGlobal("objectStoreClient");

    if    (isOS() eq "TEST") {
        $code .= "${indent}if [ -e $basep/$store/info ] ; then\n";
        $code .= "${indent}  echo Stashing $store\n";
        $code .= "${indent}  tar -C $basep -cf - $store | $client upload --path $store.tar -\n";
        $code .= "${indent}fi\n";
    }
    elsif (isOS() eq "DNANEXUS") {
    }
    else {
    }

    return($code);
}
