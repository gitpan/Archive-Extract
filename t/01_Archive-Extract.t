BEGIN { chdir 't' if -d 't' };

use strict;
use lib qw[../lib];

use Cwd                         qw[cwd];
use Test::More                  qw[no_plan];
use File::Spec; 
use Data::Dumper;
use Module::Load::Conditional   qw[check_install];


my $Debug   = $ARGV[0] ? 1 : 0;

my $Class   = 'Archive::Extract';
my $OutFile = 'a';
my $Self    = File::Spec->rel2abs( cwd() );
my $SrcDir  = File::Spec->catdir( $Self,'src' );
my $OutDir  = File::Spec->catdir( $Self,'out' );     
my $OutPath = File::Spec->catfile( $OutDir, $OutFile );

use_ok($Class);

### set verbose if debug is on ###
### stupid stupid silly stupid warnings silly! ###
$Archive::Extract::VERBOSE  = $Archive::Extract::VERBOSE = $Debug;
$Archive::Extract::WARN     = $Archive::Extract::WARN    = $Debug ? 1 : 0;

my $tmpl = {
    'x.tgz'     => {    programs    => [qw[gzip tar]],
                        modules     => [qw[Archive::Tar IO::Zlib]],
                        method      => 'is_tgz'
                    },
    'x.tar.gz' => {     programs    => [qw[gzip tar]],
                        modules     => [qw[Archive::Tar IO::Zlib]],
                        method      => 'is_tgz'
                    },
    'x.tar' => {    programs    => [qw[tar]],
                    modules     => [qw[Archive::Tar]],
                    method      => 'is_tar'
                },
    'x.gz' => {     programs    => [qw[gzip]],
                    modules     => [qw[Compress::Zlib]],
                    method      => 'is_gz'
                },
    'x.zip' => {    programs    => [qw[unzip]],
                    modules     => [qw[Archive::Zip]],
                    method      => 'is_zip'
                },
};                


for my $switch (0,1) {
    local $Archive::Extract::PREFER_BIN = $switch;
    diag("Running extract with PREFER_BIN = $Archive::Extract::PREFER_BIN")
        if $Debug;   
    
    
    for my $archive (keys %$tmpl) {    
    
        diag("Extracting $archive") if $Debug;
        
        ### check first if we can do the proper
        
        my $ae = Archive::Extract->new(
                        archive => File::Spec->catfile($SrcDir,$archive) );
    
        isa_ok( $ae, $Class );
    
        my $method = $tmpl->{$archive}->{method};
        ok( $ae->$method(), "Archive type recognized properly" );
    
    ### 8 tests from here on down ###
    SKIP: {
        
        ### check if we can run this test ###
        my $pgm_fail; my $mod_fail;
        for my $pgm ( @{$tmpl->{$archive}->{programs}} ) {
            $pgm_fail++ unless $Archive::Extract::PROGRAMS->{$pgm} &&
                               $Archive::Extract::PROGRAMS->{$pgm}; 
                    
        }
        
        for my $mod ( @{$tmpl->{$archive}->{modules}} ) {
            $mod_fail++ unless check_install( module => $mod );
        }
        
        skip "No binaries or modules to extract ".$archive, 8
            if $mod_fail && $pgm_fail;
        
        
        for my $use_buffer (1,0) {

            ### test buffers ###
            my $turn_off = !$use_buffer &&!$pgm_fail &&                 
                            $Archive::Extract::PREFER_BIN;
                           
            ### whitebox test ###
            ### stupid warnings ###
            local $IPC::Cmd::USE_IPC_RUN    = 0 if $turn_off;
            local $IPC::Cmd::USE_IPC_RUN    = 0 if $turn_off;
            local $IPC::Cmd::USE_IPC_OPEN3  = 0 if $turn_off;
            local $IPC::Cmd::USE_IPC_OPEN3  = 0 if $turn_off;
            
            ### try extracting ###
            my $to = $ae->is_gz ? $OutPath : $OutDir;
    
            my $rv = $ae->extract( to => $to );
            
            ok( $rv,            "extract() for '$archive' reports success" );
        
            diag("Extractor was: " . $ae->_extractor) if $Debug;
            
            SKIP: {
                skip "No buffers available", 6,
                    if $ae->error =~ /^No buffer captured/;
                    
                is( scalar @{ $ae->files || []}, 1,
                                    "Found correct number of output files" );
                is( $ae->files->[0], $OutFile,
                                    "Found correct output file '$OutFile'" );
            
                ok( -e $OutPath,    "Output file '$OutPath' exists" );
                ok( $ae->extract_path,
                                    "Extract dir found" );
                ok( -d $ae->extract_path,
                                    "Extract dir exists" );                       
                is( $ae->extract_path, $OutDir,
                                    "Extract dir is expected path '$OutDir'" );
            }
        
            unlink $OutPath;
            ok( !(-e $OutPath), "Output file succesfully removed" );

        }            
    } }
}



