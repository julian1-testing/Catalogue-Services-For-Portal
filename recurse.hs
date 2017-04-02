
-- {-# LANGUAGE OverloadedStrings #-}
-- {-# LANGUAGE Arrows, NoMonomorphismRestriction #-}

-- needed for disambiguating types,
{-# LANGUAGE ScopedTypeVariables, OverloadedStrings #-}

{-# LANGUAGE QuasiQuotes #-}


import Database.PostgreSQL.Simple

import Text.RawString.QQ

import qualified Data.Map as Map

-- rather than doing multiple db queries - it may be easier to just load everything into memory and then
-- query. 
-- BUT - first - we need to get the counts being returned and then propagating up

-- So it will always require a custom query....
-- also we need to be returning for all vocab not just parameter

-- IMPORTANT
-- getting everything in one query is fast - 20ms
-- lets try to join on the counts

-- IMPORTANT
-- are we sure we cannot use a groupby on the facet_count_view to get the counts ...
-- this would make client side stuff a lot simpler.


pad s count =
  case count == 0 of
    True -> s
    False -> pad (" " ++ s) (count - 1)



getAllConcepts conn  = do
  let query1 = [r|
        select 
          concept_id, 
          count,
          label,
          parent_id
        from facet_count_view2
  |]

  -- note the parent may be null! beautiful...
  xs :: [ (Integer, Integer, String, Maybe Integer) ] <- query conn query1 ()
  mapM print xs
  return ()









main :: IO ()
main = do



  let m = Map.empty 
  let m' = Map.insert 5 "123" m
  -- let m'' = Map.insert 6 456 m'

  putStrLn $ (Map.!) m'  5  

  conn <- connectPostgreSQL "host='postgres.localnet' dbname='harvest' user='harvest' sslmode='require'"


  getAllConcepts conn

{-
  let query1 = [r|
        select id, label
        from concept_view
        where parent_id is null
  |]

        -- and scheme_title ~ ?

  -- let url = "Platform"  :: String
  let url = "Parameter"  :: String

  xs :: [ (Integer, String) ] <- query conn query1 () -- (Only url)

  mapM (recurse conn 0) xs
-}
  return ()


{-

recurse conn depth (parent_id, label) = do
  putStrLn $ (pad "" $ depth * 3) ++ "- " ++ show parent_id ++ " " ++ label

  let query1 = [r|
        select id, label
        from concept_view
        where parent_id = ?
  |]
  xs :: [ (Integer, String) ] <- query conn query1 (Only parent_id)
  mapM (recurse conn $ depth + 1) xs
  return ()


-}
