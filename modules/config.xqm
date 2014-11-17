xquery version "3.0";

(:~
 : A set of helper functions to access the application context from
 : within a module.
 :)
module namespace config="https://github.com/peterstadler/odd-validation/modules/config";

declare namespace templates="http://exist-db.org/xquery/templates";

(: 
    Determine the application root collection from the current module load path.
:)
declare variable $config:app-root := 
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
        substring-before($modulePath, "/modules")
;

(:
    ****************
    General Settings START
    ****************
:)
declare variable $config:tei-schema-dir := $config:app-root || "/schemas";
declare variable $config:TEItemplate := doc('/db/apps/odd-tools/templates/results.xml');
declare variable $config:valid-request-params := ('version', 'task', 'xmlFile', 'oddFile', 'strip-external-ns', 'token', 'fragment');
(:
    ****************
    General Settings END
    ****************
:)

(:~
 : Get tei_all schema
 :
 : @param $version The TEI P5 version, e.g. 2.7.0 
 : @return The schema document
~:)
declare function config:tei-schema($version as xs:string) as document-node()? {
    let $fileName := 
        if($version eq 'current') then max(xmldb:get-child-resources($config:tei-schema-dir))
        else 'tei_all.' || $version || '.rng'
    let $filePath := string-join(($config:tei-schema-dir, $fileName), '/')
    return
        if(doc-available($filePath)) then doc($filePath)
        else ()
};

(:~
 : Get P5 source
 :
 : @param $version The TEI P5 version, e.g. 2.7.0 
 : @return The p5subset.xml document node
~:)
declare function config:p5subset($version as xs:string) as document-node()? {
    (: TODO needs to be fleshed out! :)
    doc($config:app-root || '/p5sources/p5subset.xml')
};
