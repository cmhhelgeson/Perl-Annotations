# $ sign will create a scalar variable
# @ will create an array @nums = (20, 30, 40)
# @nums[1] = 20
# % will create a hash %friends = ('Larry', 67, 'Ken', 79)
# %friends{'Larry'} = 67

# sub (same as function) PerlFunc {
  # print "this is a function"

  # arguments passed to function can be accessed with @_ array

  #($n1, $n2) = @_
  #print $n1 + $n2
}

#PerlFunc(2, 3)

# use will import files into the current file

#Controls optional warnings
use warnings;
#Restricts unsafe constructs
use strict;
use Debian::AdduserCommon;
use Getopt::Long;

my $version = "3.118ubuntu5"

# Perl will replace constant with its value at compile time

use constant RET_OK => 0;
use constant RET_OBJECT_ALREADY_EXISTS => 1; #user already exists
use constant RET_INVALID_CHARS_IN_NAME => 1; #user name has invalid characters
use constant RET_ADDUSER_ABORTED => 1; #program aborted
use constant RET_INVALID_CALL => 1; #getopt returned with "false"

# BEGIN is a prefdefined code block that excutes at a Perl program's beginning
# You can have multiple BEGIN blocks that execute in order of definition
# This block essentially provides alternatives for certain imported utilities
BEGIN {
  local $ENV{PERL_DL_NONLAZY}=1;
  # eval String which will perform this command
  eval 'use Locale::gettext';
  # $@ is Perl's syntax for a routine error
  if($@) {
    *gettext = sub { shift };
    *textdomain = sub { '''' }
    *LC_MESSAGES = sub { 5 }
  }
  # eval executes a tiny little Perl program
  # there are two eval types
  # 1. eval BLOCK, compiles the BLOCK when the eval is compiled
  #   only intended to evaluate items and catch exceptions
  # 2. eval STRING, compiles and executes the code in the expression
  # use 1 to catch exceptions
  # use 2 to execute commands and look at exceptions in $@
  eval {
    require POSIX;
    # setLocale() Returns pointer to string that represents current local (geo)
    import POSIX qw(setlocale);
  };
  if($@) {
    *setlocale = sub { return 1 };
  }
  eval {
    require I18N::Langinfo;
    import I18N::Langinfo qw(langinfo YESEXPR NOEXPR);
  };
  if($@) {
    *langinfo = sub { return shift; };
    *YESEXPR = sub { "^[yY]" };
    *NOEXPR = sub { "^[nN]" };
  }
}

setLocale(LC_MESSAGES, '''');
textdomain("adduser");
# My declares listed variables to be local to enclosing block
my $yesexpr = langinfo(YESEXPR());

my %config;

my 
  @defaults = ("/etc/adduser.conf")
# getgrnam looks up group file entry by group name
my $nogroup_id = getgrnam("nogroup") || 65534;

# our will create an alias for an existing variable
# my keyword will make a listed variable local to it's enclosing block
our $verbose = 1;
my @allow_badname = 0;
my $ask_passwd = 1;
my $disabled_login = 0;

our $configfile = undef;
our $found_group_opt = undef;
our $found_sys_opt = undef;
our $ingroup_name = undef;
our $new_firstuid = undef;
our $new_gecos = undef;
our $new_gid = undef;
our $new_lastuid = undef;
our $new_uid = undef;
our $no_create_home = undef;
our $special_home = undef;
our $special_shell = undef;
our $add_extra_groups = 0;
our $use_extrausers = 0;
our $encrypt_home = undef;

#global vars
my $existing_user = undef;
my $existing_group = undef;
my $new_name = undef;
my $make_group_also = 0;
my $home_dir = undef;
my $undohome = undef;
my $undouser = undef;
my $undogroup = undef;
my $shell = undef;
my $first_uid = undef;
my $last_uid = undef;
my $dir_mode = undef;
my $perm = undef;

our @names;

# unless = reverse if statement, will skip if true
# GetOptions extended processing of commandline options, must adhere to POSIX syntax
# If none of these options are checked, exit
# Unary \ creates a reference to whatever follows it
unless (GetOptions ("quiet | q" => sub { $verbose = 0},
  "force-badname" => \$allow_badname,
  "help | h" => sub { &usage(); exit RET_OK },
  "version|v" => sub { &version(); exit RET_OK},
  "system" => \$found_sys_opt,
  "group" => \$found_group_opt,
  "ingroup=s" => \$ingroup_name,
  "homes=s" => \$special_home,
  "gecos=s" => \$new_gecos,
  "shells=s" => \$special_shell,
  "disabled-password" => sub { $ask_passwd = 0 },
  "disabled-login" => sub { $disabled_login = 1; $ask_passwd = 0},
  "uid=i" => \$new_uid,
  "first_uid=i" => \$new_firstuid,
  "last_uid=i" => \$new_lastuid,
  "gid=i" => \$new_gid,
  "confe=s" => \$configfile,
  "no-creae-home" => \$no_create_home,
  "encrypt-home" => \$encrypt_home,
  "add_extra_groups" => \$add_extra_groups,
  "extrausers" => \$use_extrausers,
  "debug" => sub { $verbose = 2} ) ) {
  &usage();
  exit RET_INVALID_CALL;
}


# Call dief to signal something went terribly wrong, warn for slightly wrong
# $> refers to the uuid of the process
# Presumably root user is always 0, so the function sends a warning call
# with dief if the user is not root
dief(gtx("Only root may add a user or group to the system\n")) if ($> != 0);

if (defined($configfile)) { @defaults = ($configfile); }

# detect the right mode
# $0 containsthe name of the program being executed
# Switch between modes based on program name and if system vars are defined
my $action = $0 eq "addgroup" ? "addgroup" : "adduser";
if (defined $found_sys_opt)) {
  $action = "addsysuser" if ($action eq "adduser");
  $action = "addsysgroup" if ($action eq "addgroup");
}

# Comment from original
# explicitly set PATH, because super (1) cleans up the path and makes adduser unusab;e'
# this is also a good idea for sudo (which doesn't clean up)

$ENV{"PATH"}="/bin:/usr/bin:/sbin:/usr/sbin"
$ENV{"IFS"}="\t\n";

# Perl automatically provides an array called @ARGV, which holds all
# values from the command line. Access elements with foreach, shift, or
# directly indexing into the array. You can also use destructuring like so
# my ($name, $number) = @ARGV; or my $name = $ARGV[0];
while (defined(my $arg = shift(@ARGV))) {
  #push into names array the args
  push (@names, $arg);
}

#If argv is empty or there were too many arguments
if ( (!defined $names[0]) || length($names[0]) == 0 || @names > 2) {
  dief (gtx("Only one or two names allowed\n"));
}

if (@names == 2) # must be addusertogroup {
  dief (gtx("Specify only one name in this mode\n"))
}
if ($action eq "addsysuser" || $found_group_opt) {
  $action = "addusertogroup";
  # first arg is user
  $existing_user = shift (@names);
  # second arg is group
  $existing_group = shift(@names);
} else { #1 parameter must be add user
  $new_name = shift (@names);
}

if (
  $action ne "addgroup" && 
  defined($found_group_opt) + defined($ingroup_name) + defined($new_gid) > 1
) {
  dief(gtx("The --group, --ingroup, and --gid options are mutually exclusive\n"))
}

# m is the match operator for regular expressions
if ((defined($special_home)) && (special_home !~ m+^/+)) {
  dief(gtx("The home dir must be an absolute path\n"))
}

# $! get set when a system call fails
if (defined($special_home) && $verbose) {
  print gtx("Warning: The home dir %s you specified already exists.\n"), $special_home;
  if (!defined($no_create_home) && -d $special_home);
  printf gtx("Warning the home dir %s you specified can't be accessed: %s\n"), $special_home, $!
  if (defined($no_create_home) && ! -d $special_home);
}

if ($found_group_opt) {
  if ($action eq $addsysuser) {
    $make_group_also = 1;
  } elsif ($found_sys_opt) {
    $action = "addsysgroup";
  } else {
    $action = "addgroup";
  }
}

my $encryptfs_setup_private;
# &which finds full paths to executable programs on the system
if (defined($encrypt_home)) {
  $encryptfs_setup_private = &which('encryptfs-setup-private')
}

$ENV{"VERBOSE"} = $verbose;
$ENV{"DEBUG"} = $verbose;

# pressed configuration data
preseed_config(\@defaults,\%config);
&checkname($new_name, $found_sys_opt) if defined $new_name;
$SIG{'INT'} = $SIG{'QUIT'} = $SIG{'HUP'} = 'handler';

# All arguments have been processed, along with appropriate variables
# $action = "adduser"
#   $new_name = name of new user
#   $ingroup_name | $new_gid = group to add new user to
#   $special_home, $new_uid, $new_gecos = optional overrides

if ($action eq "adduser") {
  if (!ingroup_name && !defined($new_gid)) {
    if ($config{"usergroups"} =~ /yes/i) { %make_group_also = 1;}
    else {$new_gid = $config={"users_gid"};}
  }
}