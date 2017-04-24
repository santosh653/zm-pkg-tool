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

my %CFG = ();

BEGIN
{
   $GLOBAL_PATH_TO_SCRIPT_FILE = Cwd::abs_path(__FILE__);
   $GLOBAL_PATH_TO_SCRIPT_DIR  = dirname($GLOBAL_PATH_TO_SCRIPT_FILE);
   $GLOBAL_PATH_TO_TOP         = dirname($GLOBAL_PATH_TO_SCRIPT_DIR);
}

sub LoadConfiguration($)
{
   my $args = shift;

   my $cfg_name    = $args->{name};
   my $cmd_hash    = $args->{hash_src};
   my $default_sub = $args->{default_sub};

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

   if ( !defined $val )
   {
      if ($default_sub)
      {
         $val = &$default_sub($cfg_name);
         $src = "default";
      }
   }

   if ( defined $val )
   {
      if ( ref($val) eq "HASH" )
      {
         foreach my $k ( keys %{$val} )
         {
            $CFG{$cfg_name}{$k} = ${$val}{$k};

            printf( " %-25s: %-17s : %s\n", $cfg_name, $cmd_hash ? $src : "detected", $k . " => " . ${$val}{$k} );
         }
      }
      elsif ( ref($val) eq "ARRAY" )
      {
         $CFG{$cfg_name} = $val;

         printf( " %-25s: %-17s : %s\n", $cfg_name, $cmd_hash ? $src : "detected", "(" . join( ",", @{ $CFG{$cfg_name} } ) . ")" );
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

sub GetOsTag()
{
   if ( -f "/etc/redhat-release" )
   {
      chomp( my $v = `sed -n -e '1{s/[^0-9]*/r/; s/[.].*//; p;}' /etc/redhat-release` );
      return $v;
   }
   elsif ( -f "/etc/lsb-release" )
   {
      chomp( my $v = `sed -n -e '/DISTRIB_RELEASE/{s/.*=/u/; s/[.].*//; p;}' /etc/lsb-release` );
      return $v;
   }
   else
   {
      Die("Unknown OS");
   }
}

sub Init()
{
   my %cmd_hash = ();

   my @cmd_args = (
      { name => "CFG_DIR",          type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return "pkg-spec"; }, },
      { name => "OUT_TYPE",         type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return "all"; }, },
      { name => "OUT_BASE_DIR",     type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return "build"; }, },
      { name => "OUT_TEMP_DIR",     type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return "$CFG{OUT_BASE_DIR}/tmp"; }, },
      { name => "OUT_STAGE_DIR",    type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return "$CFG{OUT_BASE_DIR}/stage"; }, },
      { name => "OUT_DIST_DIR",     type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return "$CFG{OUT_BASE_DIR}/dist"; }, },
      { name => "PKG_NAME",         type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return Die("@_ not unspecfied"); }, },
      { name => "PKG_RELEASE",      type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return Die("@_ not specified"); }, },
      { name => "PKG_OS_TAG",       type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return GetOsTag(); }, },
      { name => "PKG_VERSION",      type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return Die("@_ not specified"); }, },
      { name => "PKG_SUMMARY",      type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return Die("@_ not specified"); }, },
      { name => "PKG_INSTALL_LIST", type => "=s@", hash_src => \%cmd_hash, default_sub => sub { return Die("@_ not specified"); }, },
      { name => "PKG_DEPENDS_LIST", type => "=s@", hash_src => \%cmd_hash, default_sub => sub { return []; }, },
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

sub Build()
{
   System("rm -f '$CFG{OUT_DIST_DIR}/$CFG{PKG_NAME}'_* '$CFG{OUT_DIST_DIR}/$CFG{PKG_NAME}'-*.rpm");
   System( "rm",    "-rf", "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/" );
   System( "mkdir", "-p",  "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/" );
   System( "mkdir", "-p",  "$CFG{OUT_DIST_DIR}/" );

   if ( -f "/etc/redhat-release" )
   {
      System( "cp", "-a", "$GLOBAL_PATH_TO_SCRIPT_DIR/default-template/rpm", "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/" );
      System( "cp", "-a", "$CFG{CFG_DIR}/rpm", "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/SPECS" ) if ( -d "$CFG{CFG_DIR}/rpm" );
   }
   elsif ( -f "/etc/lsb-release" )
   {
      System( "cp", "-a", "$GLOBAL_PATH_TO_SCRIPT_DIR/default-template/debian", "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/" );
      System( "cp", "-a", "$CFG{CFG_DIR}/debian", "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/" ) if ( -d "$CFG{CFG_DIR}/debian" );
   }
   else
   {
      Die("Unknown OS");
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
                       ( $tpl_file =~ /install[.]in/ )
                       ? join( "\n", map { $_ =~ s,^/,,; $_ } @{ $CFG{PKG_INSTALL_LIST} } )
                       : join( "\n", @{ $CFG{PKG_INSTALL_LIST} } );

                     $line =~ s/[@][@]PKG_INSTALL_LIST[@][@]/$pkg_install_list/g;
                  }

                  $line =~ s/[@][@]PKG_NAME[@][@]/$CFG{PKG_NAME}/g;
                  $line =~ s/[@][@]PKG_OS_TAG[@][@]/$CFG{PKG_OS_TAG}/g;
                  $line =~ s/[@][@]PKG_RELEASE[@][@]/$CFG{PKG_RELEASE}/g;
                  $line =~ s/[@][@]PKG_VERSION[@][@]/$CFG{PKG_VERSION}/g;
                  $line =~ s/[@][@]PKG_SUMMARY[@][@]/$CFG{PKG_SUMMARY}/g;
                  $line =~ s/[@][@]PKG_DEPENDS_LIST[@][@]/@{[join(",",@{$CFG{PKG_DEPENDS_LIST}})]}/g;

                  print FDw $line;
               }

               close(FDr);
               close(FDw);

               unlink($tpl_file);
            }
         },
      },
      "$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}"
   );

   System("make -f '$CFG{CFG_DIR}/$CFG{PKG_NAME}/Makefile' 'PKG_NAME=$CFG{PKG_NAME}' 'PKG_STAGE_DIR=$CFG{OUT_STAGE_DIR}/$CFG{PKG_NAME}' stage")
     if ( -f "$CFG{CFG_DIR}/$CFG{PKG_NAME}/Makefile" );

   System("ant -f '$CFG{CFG_DIR}/$CFG{PKG_NAME}/build.xml' '-DPKG_NAME=$CFG{PKG_NAME}' '-DPKG_STAGE_DIR=$CFG{OUT_STAGE_DIR}/$CFG{PKG_NAME}' stage")
     if ( -f "$CFG{CFG_DIR}/$CFG{PKG_NAME}/build.xml" );

   if ( -f "/etc/redhat-release" )
   {
      my $pkg_type_opts = "-ba";
      $pkg_type_opts = "-bb" if ( $CFG{OUT_TYPE} eq "binary" );
      $pkg_type_opts = "-bs" if ( $CFG{OUT_TYPE} eq "source" );

      my $CWD = getcwd();

      System("mkdir -p '$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/BUILDROOT/'");
      System("cp -a -t '$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/BUILDROOT/' '$CFG{OUT_STAGE_DIR}/$CFG{PKG_NAME}/'*");
      System("rpmbuild -v --define '_topdir $CWD/$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}' '--buildroot=$CWD/$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/BUILDROOT/' $pkg_type_opts '$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/rpm'/1.spec");

      print "\n\n";
      print "=========================================================================================================\n";
      System("mv -v '$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/SRPMS/'*.rpm '$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/RPMS'/*/*.rpm '$CFG{OUT_DIST_DIR}/'");
      print "=========================================================================================================\n";
   }
   elsif ( -f "/etc/lsb-release" )
   {
      my $pkg_type_opts = "-uc -us";
      $pkg_type_opts .= " -b" if ( $CFG{OUT_TYPE} eq "binary" );
      $pkg_type_opts .= " -S" if ( $CFG{OUT_TYPE} eq "source" );

      System("cp -a -t '$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}/' '$CFG{OUT_STAGE_DIR}/$CFG{PKG_NAME}'/*");
      System("cd '$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}' && dpkg-buildpackage $pkg_type_opts");

      print "\n\n";
      print "=========================================================================================================\n";
      System("mv -v '$CFG{OUT_TEMP_DIR}/$CFG{PKG_NAME}'_*.* '$CFG{OUT_DIST_DIR}/'");
      print "=========================================================================================================\n";
   }
   else
   {
      Die("Unknown OS");
   }
}


sub main()
{
   Init();
   Build();
}

main();
