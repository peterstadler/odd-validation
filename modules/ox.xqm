xquery version "3.0";

(:~
 : A set of helper functions for fetching and converting ODD files
~:)

module namespace ox="https://github.com/peterstadler/odd-validation/modules/ox";

declare namespace edirom="http://www.edirom.de";
import module namespace expath-http="http://expath.org/ns/http-client";
import module namespace config="https://github.com/peterstadler/odd-validation/modules/config" at "config.xqm";
import module namespace functx="http://www.functx.com";


(:~
 : Fetch ODD file from a processing instruction of a TEI document 
 :
 : @param $doc The TEI file
 : @return The corresponding ODD file 
~:)
declare function ox:get-odd-from-pi($doc as document-node()?) as map(*)? {
    let $pi := ($doc/processing-instruction()[contains(., 'schematypens="http://www.tei-c.org/ns/1.0"')])[1]
    let $tokens := tokenize(normalize-space($pi), '\s')
    let $url := if($tokens = 'schematypens="http://www.tei-c.org/ns/1.0"') then substring-before(substring-after($tokens[starts-with(., 'href')], '"'), '"') else ()
    let $oddFileName := functx:substring-after-last($url, '/')
    let $req := <http:request href="{$url}" method="get"/>
    let $response := if($url castable as xs:anyURI) then expath-http:send-request($req) else ()
    let $response-status := $response[1]/xs:int(@status)
    let $oddFile := 
        if($response-status = 200) then
            if($response[2] instance of document-node()) then $response[2]
            else if($response[2] instance of xs:string) then
                try { parse-xml($response[2]) }
                catch * {()}
            else if($response[2] instance of xs:base64Binary) then
                try { parse-xml(util:binary-to-string($response[2])) }
                catch * {()}
            else ()
        else ()
    return 
        if($oddFile) then map { $oddFileName := $oddFile }
        else ()
};
