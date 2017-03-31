-- stack --install-ghc --resolver lts-5.13 runghc --package http-conduit

-- {-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE Arrows, NoMonomorphismRestriction #-}

-- needed for disambiguating types,
{-# LANGUAGE ScopedTypeVariables, OverloadedStrings #-}

{-# LANGUAGE QuasiQuotes #-}


import Text.XML.HXT.Core

import Network.HTTP.Client
import Network.HTTP.Client.TLS
import Network.HTTP.Types.Status (statusCode)

-- TODO import qualified
import Network.HTTP.Types.Method
import Network.HTTP.Types.Header

import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy.Char8 as BLC


import Database.PostgreSQL.Simple

import Text.RawString.QQ

import Data.Char (isSpace)

{-
  catalogue-imos, pot, and WMS
  https://github.com/aodn/chef-private/blob/master/data_bags/imos_webapps_geonetwork_harvesters/catalogue_imos.json
-}

-- import qualified Prelude as P


parseXML s = readString [ withValidate no
    , withRemoveWS yes  -- throw away formating WS
    ] s


atTag tag = deep (isElem >>> hasName tag)


-- limit to just the wms/wfs stuff.
--



doHTTPGET url = do
    let settings = tlsManagerSettings { managerResponseTimeout = responseTimeoutMicro $ 60 * 1000000 }
    manager <- newManager settings
    request <- parseRequest url
    response <- httpLbs request manager
    -- Prelude.putStrLn $ "The status code was: " ++ (show $ statusCode $ responseStatus response)
    return response




-- IMPORTANT must close!!!
-- responseClose :: Response a -> IO ()

doHTTPPost url body = do
    let settings = tlsManagerSettings  {
        managerResponseTimeout = responseTimeoutMicro $ 60 * 1000000
    }
    manager <- newManager settings
    -- get initial request
    initialRequest <- parseRequest url
    -- modify for post
    let request = initialRequest {
        method = BC.pack "POST",
        requestBody = RequestBodyBS $ BC.pack body,
        requestHeaders = [
            (hContentType, BC.pack "application/xml")
        ]
    }
    response <- httpLbs request manager
    Prelude.putStrLn $ "The status code was: " ++ (show $ statusCode $ responseStatus response)
    return response


parseIdentifiers = atTag "csw:SummaryRecord" >>>
  proc l -> do
    identifier <- getChildren >>> hasName "dc:identifier" >>> getChildren >>> getText -< l
    title      <- getChildren >>> hasName "dc:title" >>> getChildren >>> getText -< l
    returnA -< (identifier, title)



-- TODO need to think about the transaction boundary
-- DO NOT COMBINE DATABASSE WITH RETRIEVAL

doCSWGetRecords = do
    let url = "https://catalogue-portal.aodn.org.au/geonetwork/srv/eng/csw"
    -- putStrLn query
    response <- doHTTPPost url query
    let s = BLC.unpack $ responseBody response
    identifiers <- runX (parseXML s  >>> parseIdentifiers)
    -- print
    mapM (putStrLn.format) identifiers
    return identifiers
    where
      format (identifier,title) = identifier ++ " -> " ++ title

      query = [r|<?xml version="1.0" encoding="UTF-8"?>
        <csw:GetRecords xmlns:csw="http://www.opengis.net/cat/csw/2.0.2" service="CSW" version="2.0.2"
            resultType="results" startPosition="1" maxRecords="5" outputFormat="application/xml"  >
          <csw:Query typeNames="csw:Record">
            <csw:Constraint version="1.1.0">
              <Filter xmlns="http://www.opengis.net/ogc" xmlns:gml="http://www.opengis.net/gml">
                <PropertyIsLike wildCard="%" singleChar="_" escape="\\">
                  <PropertyName>AnyText</PropertyName>
                  <Literal>%</Literal>
                </PropertyIsLike>
              </Filter>
            </csw:Constraint>
          </csw:Query>
        </csw:GetRecords>
      |]


-- OLD storing code
-- store to db
-- let storeToDB (identifier,title) = execute conn "insert into catalog(uuid,title) values (?, ?)" [identifier, title]
-- mapM storeToDB identifiers

-- further process each record,
-- TODO this should return the list of identifiers - rather than use continuation pasing style

-- mapM (\(identifier,title) -> doCSWGetRecordById conn identifier title) identifiers




-- https://catalogue-portal.aodn.org.au/geonetwork/srv/eng/csw?request=GetRecordById&service=CSW&version=2.0.2&elementSetName=full&id=4402cb50-e20a-44ee-93e6-4728259250d2&outputSchema=http://www.isotc211.org/2005/gmd
-- ok now we want to go through the actual damn records,


parseOnlineResources = atTag "gmd:CI_OnlineResource" >>>
  proc l -> do
    protocol    <- atTag "gmd:protocol" >>> getChildren >>> hasName "gco:CharacterString" >>> getChildren >>> getText -< l
    linkage     <- atTag "gmd:linkage"  >>> getChildren >>> hasName "gmd:URL" >>> getChildren >>> getText -< l
    description <- atTag "gmd:description" >>> getChildren >>> hasName "gco:CharacterString" >>> getChildren >>> getText -< l
    returnA -< (protocol, linkage, description)

-- https://catalogue-portal.aodn.org.au/geonetwork/srv/eng/csw?request=GetRecordById&service=CSW&version=2.0.2&elementSetName=full&id=0a21e0b9-8acb-4dc2-8c82-57c3ea94dd85&outputSchema=http://www.isotc211.org/2005/gmd

parseDataParameters = atTag "mcp:dataParameter" >>>
  proc l -> do
    term <- atTag "mcp:DP_DataParameter"
      >>> getChildren >>> hasName "mcp:parameterName"
      >>> getChildren >>> hasName "mcp:DP_Term" -< l

    txt  <- getChildren >>> hasName "mcp:term"  >>> getChildren >>> hasName "gco:CharacterString" >>> getChildren >>> getText -< term
    url  <- getChildren >>> hasName "mcp:vocabularyTermURL"  >>> getChildren >>> hasName "gmd:URL" >>> getChildren >>> getText -< term

    returnA -< (txt, url)


-- Or combine the parsing, and the sql actions.
-- we need to have the vocab imported - before we can do the lookups.
-- only need broader and narrower,

-- use hask. rdf library, or sql. - shouldn't be too hard to capture this stuff relationally. it's just one table.

-- TODO separate out retrieving the record and decoding the xml document,.
-- eg. separate out the online resource from the facet search term stuff.

-- function is wrongly named, since it is decoding the online resources also,
-- should we pass both title the uuid



stripSpace = filter $ not.isSpace


getCSWGetRecordById uuid title = do
    -- TODO - pass the catalog as a parameter - or pre-apply the whole thing.
    putStrLn $ concatMap id [ title, " ", uuid, " ", url ]
    response <- doHTTPGET url
    putStrLn $ "  The status code was: " ++ (show $ statusCode $ responseStatus response)
    let s = BLC.unpack $ responseBody response
    -- putStrLn s
    return s
    where
      url = stripSpace $ [r|
        https://catalogue-portal.aodn.org.au
        /geonetwork/srv/eng/csw
        ?request=GetRecordById
        &service=CSW
        &version=2.0.2
        &elementSetName=full
        &outputSchema=http://www.isotc211.org/2005/gmd
        &id= |] ++ uuid



----------------

processRecordUUID conn uuid title = do
  execute conn "insert into record(uuid,title) values (?, ?)"   
    (uuid :: String, title :: String)


----------------
-- resources

processOnlineResource conn uuid (protocol,linkage, description) = do
    execute conn [r|
      insert into resource(record_id,protocol,linkage, description) 
      values (
        (select id from record where uuid = ?), ?, ?, ?
      )
    |] (uuid :: String, protocol :: String, linkage, description)

    putStrLn "stored resource"


processOnlineResources conn uuid recordText = do
    onlineResources <- runX (parseXML recordText >>> parseOnlineResources)
    putStrLn $ (show.length) onlineResources
    mapM (putStrLn.show) onlineResources
    mapM (processOnlineResource conn uuid) onlineResources


----------------
-- data parameters

processDataParameter conn uuid (term, url) = do
    -- look up the required concept
    xs :: [ (Integer, String) ] <- query conn "select id, label from concept where url = ?" (Only url)
    -- putStrLn $ (show.length) xs 
    case length xs of
      1 -> do
        -- store the concept
        let (concept_id, concept_label) : _ = xs
        execute conn [r|
          insert into facet(concept_id, record_id) 
          values (?, (select record.id from record where record.uuid = ?))
        |] (concept_id :: Integer, uuid :: String) 
        return ()
        
      0 -> putStrLn "dataParameter not found"
      _ -> putStrLn "multiple dataParameters?"


processDataParameters conn uuid recordText = do
    dataParameters <- runX (parseXML recordText >>> parseDataParameters)
    putStrLn $ (show.length) dataParameters
    mapM (putStrLn.show) dataParameters
    mapM (processDataParameter conn uuid) dataParameters


----------------


main :: IO ()
main = do
  conn <- connectPostgreSQL "host='postgres.localnet' dbname='harvest' user='harvest' sslmode='require'"
  -- execute conn "truncate resource;"  ()
  -- note that the sequence will update -
  execute conn "delete from resource *" ()
  execute conn "delete from facet *" ()
  execute conn "delete from record *" ()

  -- doCSWGetRecords conn
  -- https://github.com/aodn/chef-private/blob/master/data_bags/imos_webapps_geonetwork_harvesters/catalogue_imos.json
  -- actually

  identifiers <- doCSWGetRecords


  let uuid = "4402cb50-e20a-44ee-93e6-4728259250d2"
  record <- getCSWGetRecordById uuid "my argo"

  processRecordUUID conn uuid "my argo"

  processDataParameters conn uuid record

  processOnlineResources conn uuid record

  return ()

