#!/usr/bin/perl

use strict;
use warnings;

use Config;
use Cwd;
use Data::Dumper;
use File::Basename;
use File::Copy;
use File::Find;
use File::Path qw/make_path/;
use Getopt::Long;
use IPC::Cmd qw/run can_run/;
use Term::ANSIColor;

my $GLOBAL_PATH_TO_SCRIPT_FILE;
my $GLOBAL_PATH_TO_SCRIPT_DIR;
my $GLOBAL_PATH_TO_TOP;
my $CWD;

my %CFG = ();

BEGIN
{
   $ENV{ANSI_COLORS_DISABLED} = 1 if ( ! -t STDOUT );
   $GLOBAL_PATH_TO_SCRIPT_FILE = Cwd::abs_path(__FILE__);
   $GLOBAL_PATH_TO_SCRIPT_DIR  = dirname($GLOBAL_PATH_TO_SCRIPT_FILE);
   $GLOBAL_PATH_TO_TOP         = dirname($GLOBAL_PATH_TO_SCRIPT_DIR);
   $CWD                        = getcwd();
}

sub LoadConfiguration($)
{
   my $args = shift;

   my $cfg_name     = $args->{name};
   my $cmd_hash     = $args->{hash_src};
   my $default_sub  = $args->{default_sub};
   my $validate_sub = $args->{validate_sub};

   my $val;
   my $src;

   if ( !defined $val )
   {
      y/A-Z_/a-z-/ foreach ( my $cmd_name = $cfg_name );

      if ( $cmd_hash && exists $cmd_hash->{$cmd_name} )
      {
         $val = $cmd_hash->{$cmd_name};
         $src = "cmdline";
      }
   }

   if ( !defined $val )
   {
      if ( $CFG{CFG_DIR} )
      {
         my $file = "$CFG{CFG_DIR}/config.pl";
         my $hash = LoadProperties($file)
           if ( -f $file );

         if ( $hash && exists $hash->{$cfg_name} )
         {
            $val = $hash->{$cfg_name};
            $src = "config"
         }
      }
   }

   my $valid = 1;

   if ( defined $val )
   {
      $valid = &$validate_sub($val)
        if ($validate_sub);
   }

   if ( !defined $val || !$valid )
   {
      if ($default_sub)
      {
         $val = &$default_sub($cfg_name);
         $src = "default" . ( $valid ? "" : "($src was rejected)" );
      }
   }

   if ( defined $val )
   {
      $valid = &$validate_sub($val)
        if ($validate_sub);

      if ( ref($val) eq "HASH" )
      {
         foreach my $k ( keys %{$val} )
         {
            $CFG{$cfg_name}{$k} = ${$val}{$k};

            printf( " %-25s: %-17s : %s\n", $cfg_name, $cmd_hash ? $src : "detected", "{" . $k . " => " . ${$val}{$k} . "}" );
         }
      }
      elsif ( ref($val) eq "ARRAY" )
      {
         $CFG{$cfg_name} = $val;

         printf( " %-25s: %-17s : %s\n", $cfg_name, $cmd_hash ? $src : "detected", "[" . join( ", ", @{ $CFG{$cfg_name} } ) . "]" );
      }
      else
      {
         $CFG{$cfg_name} = $val;

         printf( " %-25s: %-17s : %s\n", $cfg_name, $cmd_hash ? $src : "detected", $val );
      }
   }
}


sub Die($;$)
{
   my $msg  = shift;
   my $info = shift || "";
   my $err  = "$!";

   print "\n";
   print "\n";
   print "=========================================================================================================\n";
   print color('red') . "FAILURE MSG" . color('reset') . " : $msg\n";
   print color('red') . "SYSTEM ERR " . color('reset') . " : $err\n"  if ($err);
   print color('red') . "EXTRA INFO " . color('reset') . " : $info\n" if ($info);
   print "\n";
   print "=========================================================================================================\n";
   print color('red');
   print "--Stack Trace--\n";
   my $i = 1;

   while ( ( my @call_details = ( caller( $i++ ) ) ) )
   {
      print $call_details[1] . ":" . $call_details[2] . " called from " . $call_details[3] . "\n";
   }
   print color('reset');
   print "\n";
   print "=========================================================================================================\n";

   die "END";
}


sub assert($$;$)
{
   my $l = shift || "";
   my $r = shift || "";
   my $m = shift || "";

   Die( $m, "Got:[$l] != Exp:[$r]" )
     if ( $l ne $r );
}

sub LoadProperties($)
{
   my $f = shift;

   my $x = SlurpFile($f);

   my @cfg_kvs =
     map { $_ =~ s/^\s+|\s+$//g; $_ }    # trim
     map { split( /=/, $_, 2 ) }         # split around =
     map { $_ =~ s/#.*$//g; $_ }         # strip comments
     grep { $_ !~ /^\s*#/ }              # ignore comments
     grep { $_ !~ /^\s*$/ }              # ignore empty lines
     @$x;

   my %ret_hash = ();
   for ( my $e = 0 ; $e < scalar @cfg_kvs ; $e += 2 )
   {
      my $probe_key = $cfg_kvs[$e];
      my $probe_val = $cfg_kvs[ $e + 1 ];

      if ( $probe_key =~ /^%(.*)/ )
      {
         my @val_kv_pair = split( /=/, $probe_val, 2 );

         $ret_hash{$1}{ $val_kv_pair[0] } = $val_kv_pair[1];
      }
      else
      {
         $ret_hash{$probe_key} = $probe_val;
      }
   }

   return \%ret_hash;
}


sub SlurpFile($)
{
   my $f = shift;

   open( FD, "<", "$f" ) || Die( "In open for read", "file='$f'" );

   chomp( my @x = <FD> );
   close(FD);

   return \@x;
}

sub System(@)
{
   my $cmd_str = "@_";

   print color('green') . "#: pwd=@{[Cwd::getcwd()]}" . color('reset') . "\n";
   print color('green') . "#: $cmd_str" . color('reset') . "\n";

   $! = 0;
   my ( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) = run( command => \@_, verbose => 1 );

   Die( "cmd='$cmd_str'", $error_message )
     if ( !$success );

   return { msg => $error_message, out => $stdout_buf, err => $stderr_buf };
}

sub GetPkgFormat()
{
   if ( -f "/etc/redhat-release" )
   {
      return "rpm";
   }
   elsif ( -f "/etc/lsb-release" )
   {
      return "deb";
   }
   else
   {
      Die("Unknown OS");
   }
}

sub GetOsTag()
{
   our $gOSTAG;

   if ( !defined $gOSTAG )
   {
      if ( -f "/etc/redhat-release" )
      {
         chomp( $gOSTAG = `sed -n -e '1{s/[^0-9]*/r/; s/[.].*//; p;}' /etc/redhat-release` );
      }
      elsif ( -f "/etc/lsb-release" )
      {
         chomp( $gOSTAG = `sed -n -e '/DISTRIB_RELEASE/{s/.*=/u/; s/[.].*//; p;}' /etc/lsb-release` );
      }
      else
      {
         Die("Unknown OS");
      }
   }

   return $gOSTAG
}

sub _ValidateOutType($)
{
   my $ty = shift;

   if ( defined $ty )
   {
      return 1 if ( $ty eq "all" );
      return 1 if ( $ty eq "source" );
      return 1 if ( $ty eq "binary" );
   }

   return undef;
}

sub Init()
{
   my %cmd_hash = ();

   my @cmd_args = (
      {
         name         => "CFG_DIR",
         type         => "=s",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return "pkg-spec"; },
      },
      {
         name         => "OUT_TYPE",
         type         => "=s",
         hash_src     => \%cmd_hash,
         validate_sub => &_ValidateOutType,
         default_sub  => sub { return "all"; },
      },
      {
         name         => "OUT_BASE_DIR",
         type         => "=s",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return "build"; },
      },
      {
         name         => "OUT_TEMP_DIR",
         type         => "=s",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return "$CFG{OUT_BASE_DIR}/tmp"; },
      },
      {
         name         => "OUT_STAGE_DIR",
         type         => "=s",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return "$CFG{OUT_BASE_DIR}/stage"; },
      },
      {
         name         => "OUT_DIST_DIR",
         type         => "=s",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return "$CFG{OUT_BASE_DIR}/dist"; },
      },
      {
         name         => "PKG_NAME",
         type         => "=s",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return Die("@_ not unspecfied"); },
      },
      {
         name         => "PKG_RELEASE",
         type         => "=s",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return Die("@_ not specified"); },
      },
      {
         name         => "PKG_VERSION",
         type         => "=s",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return Die("@_ not specified"); },
      },
      {
         name         => "PKG_SUMMARY",
         type         => "=s",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return Die("@_ not specified"); },
      },
      {
         name         => "PKG_INSTALLS",
         type         => "=s@",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return []; },
      },
      {
         name         => "PKG_DEPENDS",
         type         => "=s@",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return []; },
      },
      {
         name         => "PKG_PRE_DEPENDS",
         type         => "=s@",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return []; },
      },
      {
         name         => "PKG_PROVIDES",
         type         => "=s@",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return []; },
      },
      {
         name         => "PKG_CONFLICTS",
         type         => "=s@",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return []; },
      },
      {
         name         => "PKG_OBSOLETES",
         type         => "=s@",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return []; },
      },
      {
         name         => "PKG_REPLACES",
         type         => "=s@",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return []; },
      },
      {
         name         => "PKG_PRE_INSTALL_SCRIPT",
         type         => "=s",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return undef; },
      },
      {
         name         => "PKG_POST_INSTALL_SCRIPT",
         type         => "=s",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return undef; },
      },
      {
         name         => "PKG_FORMAT",
         type         => "",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return GetPkgFormat(); },
      },
      {
         name         => "PKG_OS_TAG",
         type         => "",
         hash_src     => \%cmd_hash,
         validate_sub => undef,
         default_sub  => sub { return GetOsTag(); },
      },
   );

   {
      my @cmd_opts =
        map { $_->{opt} =~ y/A-Z_/a-z-/; $_; }    # convert the opt named to lowercase to make command line options
        map { { opt => $_->{name}, opt_s => $_->{type} } }    # create a new hash with keys opt, opt_s
        grep { $_->{type} }                                   # get only names which have a valid type
        @cmd_args;

      my $help_func = sub {
         print "Usage: $0 <options>\n";
         print "Supported options: \n";
         print "   --" . "$_->{opt}$_->{opt_s}\n" foreach (@cmd_opts);
         exit(0);
      };

      if ( !GetOptions( \%cmd_hash, ( map { $_->{opt} . $_->{opt_s} } @cmd_opts ), help => $help_func ) )
      {
         print Die("wrong commandline options, use --help");
      }
   }

   print "=========================================================================================================\n";
   LoadConfiguration($_) foreach (@cmd_args);
   print "=========================================================================================================\n";
}


sub _SanitizePkgList($)
{
   my $list = shift;

   my $san_list = "";
   foreach my $entry ( @{$list} )
   {
      $entry =~ s/\s//g;
      $entry =~ s/\<or\>/|/g;
      $entry =~ s/[|][|]*/|/g;

      my @comp = split( /[|]/, $entry );

      my $san_entry = "";
      foreach my $comp_entry (@comp)
      {
         # abc-2.5            -> $pkn
         # abc-2.5>=2.1.0-1   -> $pkn$cmp$ver
         # abc-2.5(>=2.1.0-1) -> $pkn($cmp$ver)
         if ( $comp_entry =~ m/^([^>=<]+)([>=<]*)(.*)$/ )
         {
            my $pkn = $1;
            my $cmp = $2;
            my $ver = $3;

            $pkn =~ s/[(]$//;
            $ver =~ s/[)]$//;

            my $no_add_os_tag = 1
              if ( $ver =~ s/[!]$// );

            my $san_comp = "";

            if ($pkn)
            {
               $san_comp = $pkn;

               if ( $cmp && $ver )
               {
                  my $tag = ( !$no_add_os_tag && $ver =~ m/[-][^-]*$/ ) ? ".$CFG{PKG_OS_TAG}" : "";

                  if ( $CFG{PKG_FORMAT} eq "deb" )
                  {
                     $cmp = ">>" if ( $cmp eq ">" );
                     $cmp = "<<" if ( $cmp eq "<" );
                     $cmp = "="  if ( $cmp eq "==" );

                     $san_comp .= " (" . $cmp . " " . $ver . "$tag)";
                  }
                  if ( $CFG{PKG_FORMAT} eq "rpm" )
                  {
                     $cmp = ">" if ( $cmp eq ">>" );
                     $cmp = "<" if ( $cmp eq "<<" );
                     $cmp = "=" if ( $cmp eq "==" );

                     $san_comp .= " " . $cmp . " " . $ver . "$tag";
                  }
               }
            }

            $san_entry .= ( $san_entry && $san_comp ? " | " : "" ) . $san_comp
              if ( $CFG{PKG_FORMAT} eq "deb" );
            $san_entry .= ( $san_entry && $san_comp ? " or " : "" ) . $san_comp
              if ( $CFG{PKG_FORMAT} eq "rpm" );
         }
      }

      $san_list .= ( $san_list && $san_entry ? ", " : "" ) . $san_entry;
   }

   return $san_list;
}


sub Build()
{
   System( "rm", "-f", $_ ) foreach glob("$CFG{OUT_DIST_DIR}/$CFG{PKG_OS_TAG}/$CFG{PKG_NAME}_*");
   System( "rm", "-f", $_ ) foreach glob("$CFG{OUT_DIST_DIR}/$CFG{PKG_OS_TAG}/$CFG{PKG_NAME}-*.rpm");

   System( "rm",    "-rf", "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/" );
   System( "mkdir", "-p",  "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/" );
   System( "mkdir", "-p",  "$CFG{OUT_DIST_DIR}/$CFG{PKG_OS_TAG}/" );

   my $pkg_pre_install_list = "";
   my $pkg_post_install_list = "";
   if ( defined $CFG{PKG_POST_INSTALL_SCRIPT}) {
      open FILE, "$CFG{PKG_POST_INSTALL_SCRIPT}" or die "Couldn't open postinst file: $!";
      $pkg_post_install_list = join("", <FILE>);
      close FILE;
   }
   if ( defined $CFG{PKG_PRE_INSTALL_SCRIPT}) {
      open FILE, "$CFG{PKG_PRE_INSTALL_SCRIPT}" or die "Couldn't open preinst file: $!";
      $pkg_pre_install_list = join("", <FILE>);
      close FILE;
   }

   if ( $CFG{PKG_FORMAT} eq "rpm" )
   {
      System( "cp", "-a", "$GLOBAL_PATH_TO_SCRIPT_DIR/default-template/rpm", "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/" );
      System( "cp", "-a", "$CFG{CFG_DIR}/rpm", "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/SPECS" ) if ( -d "$CFG{CFG_DIR}/rpm" );
   }
   elsif ( $CFG{PKG_FORMAT} eq "deb" )
   {
      System( "cp", "-a", "$GLOBAL_PATH_TO_SCRIPT_DIR/default-template/debian", "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/" );
      System( "cp", "-a", "$CFG{CFG_DIR}/debian", "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/" ) if ( -d "$CFG{CFG_DIR}/debian" );
   }
   else
   {
      Die("Unknown PACKAGING format");
   }

   find(
      {
         wanted => sub {
            my $tpl_file = $_;
            if ( -f $tpl_file && $tpl_file =~ /[.]in$/ )
            {
               s/[.]in$// for ( my $new_file = $tpl_file );

               open( FDr, "<", "$tpl_file" );
               open( FDw, ">", "$new_file" );

               while ( my $line = <FDr> )
               {
                  {
                     my $pkg_install_list =
                       ( $CFG{PKG_FORMAT} eq "deb" && $tpl_file =~ /install[.]in/ )
                       ? join( "\n", map { $_ =~ s,^/,,; $_ } @{ $CFG{PKG_INSTALLS} } )
                       : join( "\n", @{ $CFG{PKG_INSTALLS} } );

                     $line =~ s/[@][@]PKG_INSTALLS[@][@]/$pkg_install_list/g;
                  }
                  $line =~ s/[@][@]PKG_POST_INSTALL[@][@]/$pkg_post_install_list/g;
                  $line =~ s/[@][@]PKG_PRE_INSTALL[@][@]/$pkg_pre_install_list/g;
                  $line =~ s/[@][@]PKG_NAME[@][@]/$CFG{PKG_NAME}/g;
                  $line =~ s/[@][@]PKG_RELEASE[@][@]/$CFG{PKG_RELEASE}/g;
                  $line =~ s/[@][@]PKG_OS_TAG[@][@]/$CFG{PKG_OS_TAG}/g;
                  $line =~ s/[@][@]PKG_VERSION[@][@]/$CFG{PKG_VERSION}/g;
                  $line =~ s/[@][@]PKG_SUMMARY[@][@]/$CFG{PKG_SUMMARY}/g;
                  $line =~ s/[@][@]PKG_DEPENDS[@][@]/@{[_SanitizePkgList($CFG{PKG_DEPENDS})]}/g;
                  $line =~ s/[@][@]PKG_PRE_DEPENDS[@][@]/@{[_SanitizePkgList($CFG{PKG_PRE_DEPENDS})]}/g;
                  $line =~ s/[@][@]PKG_PROVIDES[@][@]/@{[_SanitizePkgList($CFG{PKG_PROVIDES})]}/g;
                  $line =~ s/[@][@]PKG_CONFLICTS[@][@]/@{[_SanitizePkgList($CFG{PKG_CONFLICTS})]}/g;
                  $line =~ s/[@][@]PKG_OBSOLETES[@][@]/@{[_SanitizePkgList($CFG{PKG_OBSOLETES})]}/g;
                  $line =~ s/[@][@]PKG_REPLACES[@][@]/@{[_SanitizePkgList($CFG{PKG_REPLACES})]}/g;

                  if ( $line =~ m/^\s*[A-Za-z][A-Za-z_0-9-]*\s*[:](\s*,*\s*)*$/ )    # drop lines with empty headers
                  {
                  }
                  else
                  {
                     print FDw $line;
                  }
               }

               close(FDr);
               close(FDw);

               unlink($tpl_file);
            }
         },
      },
      "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}"
   );

   System( "make", "-f", "$CFG{CFG_DIR}/$CFG{PKG_NAME}/Makefile", "PKG_NAME=$CFG{PKG_NAME}", "PKG_STAGE_DIR=$CFG{OUT_STAGE_DIR}/$CFG{PKG_NAME}", "stage" )
     if ( -f "$CFG{CFG_DIR}/$CFG{PKG_NAME}/Makefile" );

   System( "ant", "-f", "$CFG{CFG_DIR}/$CFG{PKG_NAME}/build.xml", "-DPKG_NAME=$CFG{PKG_NAME}", "-DPKG_STAGE_DIR=$CFG{OUT_STAGE_DIR}/$CFG{PKG_NAME}", "stage" )
     if ( -f "$CFG{CFG_DIR}/$CFG{PKG_NAME}/build.xml" );

   if ( $CFG{PKG_FORMAT} eq "rpm" )
   {
      my @pkg_type_opts = ("-ba");
      @pkg_type_opts = ("-bb") if ( $CFG{OUT_TYPE} eq "binary" );
      @pkg_type_opts = ("-bs") if ( $CFG{OUT_TYPE} eq "source" );

      System( "mv", "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/rpm/1.spec", "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/rpm/$CFG{PKG_NAME}.spec" );
      System( "mkdir", "-p", "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/BUILDROOT/" );

      System( "cp", "-a", $_, "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/BUILDROOT/@{[basename $_]}" ) foreach glob("$CFG{OUT_STAGE_DIR}/$CFG{PKG_NAME}/*");

      {
         System( "rpmbuild", "-v", "--define", "_topdir $CWD/$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}", "--buildroot=$CWD/$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/BUILDROOT/", @pkg_type_opts, "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/rpm/$CFG{PKG_NAME}.spec" );
      }

      print "\n\n";
      print "=========================================================================================================\n";
      System( "mv", "-v", $_, "$CFG{OUT_DIST_DIR}/$CFG{PKG_OS_TAG}/" ) foreach glob("$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/SRPMS/*.rpm");
      System( "mv", "-v", $_, "$CFG{OUT_DIST_DIR}/$CFG{PKG_OS_TAG}/" ) foreach glob("$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/RPMS/*/*.rpm");
      print "=========================================================================================================\n";
   }
   elsif ( $CFG{PKG_FORMAT} eq "deb" )
   {
      my @pkg_type_opts = ( "-uc", "-us" );
      push( @pkg_type_opts, "-b" ) if ( $CFG{OUT_TYPE} eq "binary" );
      push( @pkg_type_opts, "-S" ) if ( $CFG{OUT_TYPE} eq "source" );

      System( "cp", "-a", $_, "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/@{[basename $_]}" ) foreach glob("$CFG{OUT_STAGE_DIR}/$CFG{PKG_NAME}/*");

      {
         chdir("$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}");
         System( "dpkg-buildpackage", @pkg_type_opts );
         chdir($CWD);
      }

      print "\n\n";
      print "=========================================================================================================\n";
      System( "mv", "-v", $_, "$CFG{OUT_DIST_DIR}/$CFG{PKG_OS_TAG}/" ) foreach glob("$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}_*.*");
      print "=========================================================================================================\n";
   }
   else
   {
      Die("Unknown PACKAGING format");
   }
}

sub SelfTest()
{
   if ( $CFG{PKG_FORMAT} eq "DEB" )
   {
      assert(
         _SanitizePkgList( [ "abc-3.4(>=4.4)", "def-6.7(>6.6-1)", "def-6.7(>6.6-1!)", "ghi(=7.0)", "jkl", "aaa | bbb | perl(Carp) >= 3.2" ] ),
         "abc-3.4 (>= 4.4), def-6.7 (>> 6.6-1.$CFG{PKG_OS_TAG}), def-6.7 (>> 6.6-1), ghi (= 7.0), jkl, aaa | bbb | perl(Carp) (>= 3.2)"
      );
   }

   if ( $CFG{PKG_FORMAT} eq "RPM" )
   {
      assert(
         _SanitizePkgList( [ "abc-3.4(>=4.4)", "def-6.7(>6.6-1)", "def-6.7(>6.6-1!)", "ghi(=7.0)", "jkl", "aaa | bbb | perl(Carp) >= 3.2" ] ),
         "abc-3.4 >= 4.4, def-6.7 > 6.6-1.$CFG{PKG_OS_TAG}, def-6.7 > 6.6-1, ghi = 7.0, jkl, aaa or bbb or perl(Carp) >= 3.2"
      );
   }
}


sub main()
{
   Init();
   SelfTest();
   Build();
}

main();
