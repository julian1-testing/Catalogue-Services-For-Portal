
### Build,

apt-get install cabal-install
cabal install hxt
cabal install hxt-curl
cabal install warp
# cabal install warp-tls



ghc parse.hs
./parse

# for postgres,
apt-get install libpq-dev
cabal install postgresql-simple



