

{-# LANGUAGE ScopedTypeVariables, OverloadedStrings #-}

{-
  IMPORTANT - how to wait/throttle according to the number of db connections - until one was available?

  for routes, 
    http://cjwebb.github.io/blog/2016/12/16/getting-started-with-haskells-warp/
  middleware - eg. gzip  
    http://www.yesodweb.com/book/web-application-interface   

  https://crypto.stanford.edu/~blynn/haskell/warp.html
-}


module Server where


import Network.Wai 
  (responseLBS, Application, Response, pathInfo, rawPathInfo, requestMethod, 
    remoteHost, requestHeaders, queryString, rawQueryString )
import Network.Wai.Handler.Warp (run)
import Network.HTTP.Types (status200, status404)
import Network.HTTP.Types.Header (hContentType)


import qualified Data.Text.Encoding as E(encodeUtf8)
import qualified Data.Text.Lazy.Encoding as LE(encodeUtf8)
import qualified Data.Text.Lazy as LT

-- for putStrLn
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as LBS

import qualified Database.PostgreSQL.Simple as PG(query, connectPostgreSQL)
import Database.PostgreSQL.Simple.Types as PG(Only(..))




import FacetRequest(request) 

encode = LE.encodeUtf8 


main = do
    let port = 3000
    putStrLn $ "Listening on port " ++ show port
    run port app


-- might be cleaner to format as a List
printKeyVal key val =
  BS.putStrLn $ BS.append (BS.pack key) val


app :: Application
app req res = do

  -- see, https://hackage.haskell.org/package/wai-3.2.1.1/docs/Network-Wai.html
  LBS.putStrLn $ encode "got request" 
  printKeyVal "path"          $ rawPathInfo req
  printKeyVal "rawQuery "     $ (BS.pack.show) $ rawQueryString req
  printKeyVal "pathInfo "     $ (BS.pack.show) $ pathInfo req
  printKeyVal "method "       $ requestMethod req 
  printKeyVal "host "         $ (BS.pack.show) $ remoteHost req 
  printKeyVal "headers "      $ BS.pack $ show $ requestHeaders req 

  -- params,
  let params =  queryString req 
  -- printKeyVal "params "       $ BS.pack $ show $ params
  -- putStrLn $ "length " ++ (show.length) params

  -- log params 
  putStrLn "----"
  let f (key, Just val) = BS.putStrLn $ BS.concat  [ key , E.encodeUtf8 ":", val ]  
  mapM f params
  putStrLn "----"


  -- route delegation
  x <- case (pathInfo req) of
    [ "srv","eng","xml.search.imos" ] -> whootRoute
    [ "whoot" ] -> helloRoute
    _   -> notFoundRoute

  -- do it...
  res x



whootRoute :: IO Response 
whootRoute =  do

  BS.putStrLn $ E.encodeUtf8 "in whoot" 

  -- test db 
  conn <- PG.connectPostgreSQL "host='postgres.localnet' dbname='harvest' user='harvest' sslmode='require'"
  let query = "select 123" 
  xs :: [ (Only Integer ) ] <- PG.query conn query ()
  mapM (putStrLn.show) xs

  s <- FacetRequest.request conn
  -- let ss = LT.pack s
  -- let ss = encode s
  -- LBS.putStrLn ss

  return $ 
    responseLBS status200 [(hContentType, "application/json")] .  encode $  s --"Whoot"



helloRoute :: IO Response
helloRoute = do
  LBS.putStrLn $ encode "in whoot hello" 
  return $ responseLBS status200 [(hContentType, "application/json")] . encode $ "Hello World"



notFoundRoute :: IO Response
notFoundRoute = return $ responseLBS status404 [(hContentType, "application/json")] "404 - Not Found"




-- vault - for storing data between apps and middleware.

-- ok, now need to get parameters....
-- parameters are a list in queryString 
-- eg. http://localhost:3000/sdf/sssss?x=123&y=456 -> [("x",Just "123"),("y",Just "456")]
-- and url encoding/decoding...
-- actually we are directly matching this stuff... so perhaps we need a regex.... 
-- need to urlEncode / urlDecode 
-- note also, the difference between rawPathInfo and rawQueryString...

-- https://hackage.haskell.org/package/http-types-0.9.1/docs/Network-HTTP-Types-URI.html#t:Query
-- whootRoute :: Response
-- we're going to need to pick up a db connection - so this has to be io



{-

app :: Application
app req f = do
    print "got request"

    -- this works by itself, it's using Data.Text.Text
    let a = LT.pack "čušpajž日本語"  
    let b = LT.pack " whoot"  
    let c = LT.append a b

    -- 
    let d = LE.encodeUtf8 c

    print $ LBS.unpack d -- "sending data " -- kind of works.

    -- LBS.putStrLn  LBS.unpack d

    -- x <- f $ responseLBS status200 [(hContentType, "text/plain")] d --"Hello world!" 
    -- x <- f $ responseLBS status200 [(hContentType, "text/plain")] d --"Hello world!" 
    x <- f $ responseLBS status200 [(hContentType,  "text/html; charset=utf-8")] d --"Hello world!" 

    print "done request"
    return x
-}


