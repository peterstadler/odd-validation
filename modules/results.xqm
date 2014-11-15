xquery version "3.0";

(:~
 : A set of validation tasks
 : Each must take a token (xs:string) and params (map) as input and return a tei:body element
 : They are in turn automatically exposed to the results.xql as 'task' parameter 
~:)

module namespace results="http://edirom.de/odd-tools/results";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace edirom="http://www.edirom.de";

import module namespace config="http://edirom.de/odd-tools/config" at "config.xqm";
import module namespace sess="http://edirom.de/odd-tools/sess" at "sess.xqm";
import module namespace validate="http://edirom.de/odd-tools/validate" at "validate.xqm";

(:~
 : Initialize the session by creating a session map 
 :
 : @return The updated session map
~:)
declare function results:init($token as xs:string?, $params as map(*)?) as element(tei:body) {
    <tei:body><tei:head type="sessionID">{sess:create-session-map()}</tei:head></tei:body>
};


(:~
 : Validate against tei_all
 :
 : @param $token The token of a session-map with the stored XML files
 : @param $params A map with parameters including the tei_all version ('version') and wheter to skip external namespaces ('skip-external-ns') 
 : @return A tei:body element with the validation results
~:)
declare function results:tei-validate($token as xs:string, $params as map(*)) as element(tei:body) {
    let $session-map := sess:get-session-map($token)
    let $file := $session-map('xmlFile')
    let $fragment := not($file/root()/node-name(*) = (xs:QName('tei:TEI'), xs:QName('tei:teiCorpus')))
    let $externalNS := $params('externalNS') eq 'true'
    let $validation := validate:tei-schema($file, $params('version'), $fragment, $externalNS)
    return 
        <body xmlns="http://www.tei-c.org/ns/1.0">
            <div type="properties">
                <list type="gloss">
                    {for $i in map:keys($params) return (<label>{$i}</label>,<item>{$params($i)}</item>)}
                    <label>fragment</label>
                    <item>{$fragment cast as xs:string}</item>
                    <label>rootElement</label>
                    <item>{$file/name(*) cast as xs:string}</item>
                    {for $fileName in map:keys($session-map)[ends-with(., 'Name')] return (<label>{$fileName}</label>,<item>{$session-map($fileName)}</item>)}
                </list>
            </div>
            {results:jing-report2tei($validation)}
        </body>
};


(:~
 : List all element namespaces
 :
 : @param $token The token of a session-map with the stored XML files
 : @param $params A map with parameters
 : @return A tei:body element with results of the query
~:)
declare function results:list-element-namespaces($token as xs:string, $params as map(*)?) as element(tei:body) {
    let $session-map := sess:get-session-map($token)
    let $file := $session-map('xmlFile')
    let $ns := distinct-values($file//*/namespace-uri())
(:    let $store-into-session := session:set-attribute('session-map', map:new(($session-map, map:entry('external-namespaces', $ns != 'http://www.tei-c.org/ns/1.0')))):)
    return 
        <body xmlns="http://www.tei-c.org/ns/1.0">
            <div type="properties">
                <list type="gloss">
                    {for $i in map:keys($params) return (<label>{$i}</label>,<item>{$params($i)}</item>)}
                    <label>externalNS</label>
                    <item>{$ns != 'http://www.tei-c.org/ns/1.0' cast as xs:string}</item>
                    {for $fileName in map:keys($session-map)[ends-with(., 'Name')] return (<label>{$fileName}</label>,<item>{$session-map($fileName)}</item>)}
                </list>
            </div>
            <div type="results">
                <list>
                    <head>namespaces</head>
                    {for $i in $ns return <item>{$i cast as xs:string}</item>}
                </list>
            </div>
        </body>
};

(:declare function results:compiled-odd($token as xs:string) as document-node()? {
    let $session-map := results:get-session-map($token)
    let $xml-file := $session-map('xmlFile')
    return
};:)

declare %private function results:jing-report2tei($report as element(report)) as element(tei:div) {
    <tei:div type="results">
        <tei:head type="status">{normalize-space($report/status)}</tei:head>
        {for $message in $report//message
        return 
            <tei:div type="message">
                <tei:list type="gloss">
                    {for $attr in $message/@*
                    return (<tei:label>{local-name($attr)}</tei:label>,<tei:item>{normalize-space($attr)}</tei:item>)
                    }
                    <tei:label>messageText</tei:label>
                    <tei:item>{normalize-space($message)}</tei:item>
                </tei:list>
            </tei:div>
        }
    </tei:div>
};
