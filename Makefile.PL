use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Math::Random::Xoshiro256',
    VERSION_FROM => 'lib/Math/Random/Xoshiro256.pm',
    ABSTRACT     => 'XS wrapper for xoshiro256+ PRNG',
    AUTHOR       => 'Scott Baker <bakerscot@cpan.org>',
    PL_FILES     => {},
);
