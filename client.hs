-- stack --install-ghc --resolver lts-5.13 runghc --package http-conduit

-- {-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE Arrows, NoMonomorphismRestriction #-}

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


-- QuasiQuotes may be cleaner,
-- http://kseo.github.io/posts/2014-02-06-multi-line-strings-in-haskell.html
-- alternatively use the xml constructor stuff from HXT
getRecordsQuery :: String
getRecordsQuery = unlines [
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<csw:GetRecords xmlns:csw=\"http://www.opengis.net/cat/csw/2.0.2\" service=\"CSW\" version=\"2.0.2\"    ",
    "    resultType=\"results\" startPosition=\"1\" maxRecords=\"5\" outputFormat=\"application/xml\"  >",
    "  <csw:Query typeNames=\"csw:Record\">",
    "    <csw:Constraint version=\"1.1.0\">",
    "      <Filter xmlns=\"http://www.opengis.net/ogc\" xmlns:gml=\"http://www.opengis.net/gml\">",
    "        <PropertyIsLike wildCard=\"%\" singleChar=\"_\" escape=\"\\\">",
    "          <PropertyName>AnyText</PropertyName>",
    "          <Literal>%</Literal>",
    "        </PropertyIsLike>",
    "      </Filter>",
    "    </csw:Constraint>",
    "  </csw:Query>",
    "</csw:GetRecords>" 
    ]



doGetRecords = do
    let url = "https://catalogue-portal.aodn.org.au/geonetwork/srv/eng/csw"
    response <- doHTTPPost url getRecordsQuery
    let s = BLC.unpack $ responseBody response
    -- parse out the metadata identifierss
    identifiers <- runX (parseXML s  >>> parseIdentifiers)
    -- print the records,
    let formattedlst = Prelude.map (\(identifier,title) -> identifier ++ " -> " ++ title) identifiers 
    mapM putStrLn formattedlst

    -- go process each record,
    mapM (\(identifier,title) -> doGetRecordById identifier title) identifiers 

    putStrLn "finished"




-- https://catalogue-portal.aodn.org.au/geonetwork/srv/eng/csw?request=GetRecordById&service=CSW&version=2.0.2&elementSetName=full&id=4402cb50-e20a-44ee-93e6-4728259250d2&outputSchema=http://www.isotc211.org/2005/gmd
-- ok now we want to go through the actual damn records,


parseOnlineResources = atTag "gmd:CI_OnlineResource" >>>
  proc l -> do
    -- leagName <- getAttrValue "NAME"   -< l
    protocol <- atTag "gmd:protocol" >>> getChildren >>> hasName "gco:CharacterString" >>> getChildren >>> getText -< l
    url      <- atTag "gmd:linkage"  >>> getChildren >>> hasName "gmd:URL" >>> getChildren >>> getText -< l
    returnA -< (protocol, url)


-- function is wrongly named, since it is decoding the online resources also,  
-- should we pass both title the uuid 
doGetRecordById uuid title = do
    putStrLn $ title ++ uuid
    let url = "https://catalogue-portal.aodn.org.au/geonetwork/srv/eng/csw?request=GetRecordById&service=CSW&version=2.0.2&elementSetName=full&id=" ++ uuid ++ "&outputSchema=http://www.isotc211.org/2005/gmd"
    response <- doHTTPGET url
    putStrLn $ "  The status code was: " ++ (show $ statusCode $ responseStatus response)
    let s = BLC.unpack $ responseBody response
    onlineResources <- runX (parseXML s  >>> parseOnlineResources)
    let lst = Prelude.map (\(protocol,url) -> "  " ++ protocol ++ " -> " ++ url) onlineResources
    mapM putStrLn lst

    putStrLn "  finished"


main :: IO ()
-- main = getResources
main = doGetRecords
-- main = do
--    putStrLn query
