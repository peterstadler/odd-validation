xquery version "3.0";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace edirom="http://www.edirom.de";
declare namespace expath-http="http://expath.org/ns/http-client";

import module namespace tei2tei="http://edirom.de/odd-tools/tei2tei" at "tei2tei.xqm";
import module namespace tei2json="http://edirom.de/odd-tools/tei2json" at "tei2json.xqm";
import module namespace results="http://edirom.de/odd-tools/results" at "results.xqm";
import module namespace sess="http://edirom.de/odd-tools/sess" at "sess.xqm";
import module namespace config="http://edirom.de/odd-tools/config" at "config.xqm";
import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace xqjson="http://xqilla.sourceforge.net/lib/xqjson";

(:declare option exist:serialize "method=html5 media-type=text/html enforce-xhtml=yes";:)

(: This should be set to application/tei+xml, but that makes Firefox open a fresh tab, which is annoying. :)
declare option exist:serialize "method=xml media-type=application/xml encoding=utf-8 indent=yes";

(:
    1. Create compiled ODD
    2. create Relax schema 
    3. Check valid against its own customization
    4. check valid against abstract model
:)



(: task = oddc|relax:)
(:declare function local:create-schema($odd as document-node()?, $task as xs:string) {
    let $url := 
        switch($task)
        case 'oddc' return 'http://www.tei-c.org/ege-webservice/Conversions/ODD%3Atext%3Axml/ODDC%3Atext%3Axml/'
        case 'relax' return 'http://www.tei-c.org/ege-webservice/Conversions/ODDC%3Atext%3Axml/relaxng%3Aapplication%3Axml-relaxng/'
        default return error(xs:QName('edirom:unsupported-task'), 'task' || $task || ' not supported')
    let $req := 
        <http:request href="{$url}" method="post" http-version="1.0">
            <http:multipart media-type="multipart/form-data" boundary="foobar">
                <http:header name="Content-Disposition" value='form-data; name="upload"; filename="file1.xml"'/>
                <http:body media-type="application/xml">{$odd}</http:body>
            </http:multipart>
        </http:request>
    return 
        if($odd) then 
            try { parse-xml(util:binary-to-string(expath-http:send-request($req)[2])) }
            catch * {error(xs:QName('edirom:parser-fail'), 'failed to parse as xml file')}
        else ()
};:)



declare function local:serialize-output($result as element(tei:body), $format as xs:string?) {
    switch($format)
        case 'html' return (
            (:response:set-header('Content-Type', 'text/html'),
            ():)
            error(xs:QName('edirom:format-error'), 'format "' || $format || '" not supported')
        )
        case 'json' return (
            response:set-header('Content-Type', 'application/json'),
            tei2json:serialize($result)
        )
        default return (
            response:set-header('Content-Type', 'application/xml'),
            tei2tei:dispatch($result)
        )
};


let $task := request:get-parameter('task', ())
let $token := request:get-parameter('token', ())
let $format := 
    (: controller problems: Request parameters of POST are not visible :)
    if($task = 'init') then 'json'
    else request:get-attribute('format')
let $params := map:new( for $i in request:get-parameter-names()[not(. = ('xmlFile','oddFile'))] return map:entry($i, request:get-parameter($i, ())))
(:let $log := util:log-system-out(request:get-parameter-names()):)
let $lookup := function($task as xs:string) {
    try {
        function-lookup(xs:QName('results:' || $task), 2)
    } catch * {
        error(xs:QName('edirom:task-error'), 'task "' || $task || '" not supported')
    }
}
let $result := $lookup($task)($token, $params)

return 
    local:serialize-output($result, $format)
