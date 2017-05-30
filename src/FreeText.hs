{-
    free text search across title and abstract
    - could add vocab as well by just joining concept tables
    - could build the tsvectors on record insert - if search across a much larger number of records

    see,
      http://rachbelaid.com/postgres-full-text-search-is-good-enough/
-}
{-# LANGUAGE ScopedTypeVariables, OverloadedStrings, QuasiQuotes #-}

module FreeText where

import Database.PostgreSQL.Simple as PG
import Database.PostgreSQL.Simple.Types as PG(Only(..))

import qualified Data.ByteString.Char8 as BS(ByteString(..), pack)

-- import qualified Data.ByteString.Char8 as BS-- (pack)
-- import Data.ByteString.Char8 

-- import qualified Data.ByteString.Char8 as BS(ByteString(..) )

import Text.RawString.QQ


search conn query = do
    -- BS.putStrln $ "freetext query: '" ++ query ++ "'"

    xs :: [ (Only Int)] <- PG.query conn
      [r|
          select record_id from (
            select
              record_id,
              (to_tsvector( title) || to_tsvector(abstract)) @@ to_tsquery( ?) as result
              from data_identification
            ) as x
          where x.result = true;
      |]
      $ (query :: Only BS.ByteString)

    return $
      map (\(Only record_id) -> record_id) xs


----
-- test

main = do
    conn <- PG.connectPostgreSQL "host='postgres.localnet' dbname='harvest' user='harvest' sslmode='require'"
    -- xs <- search conn "argo"
    -- xs <- search conn "argo & profiles"
    -- xs <- search conn "'argo profiles'"
    xs <- search conn ( Only $ BS.pack "'argo profiles'" )
    print xs

