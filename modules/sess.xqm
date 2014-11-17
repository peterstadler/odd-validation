xquery version "3.0";

(:~
 : A set of helper functions for storing and retrieving session information
~:)

module namespace sess="https://github.com/peterstadler/odd-validation/modules/sess";

declare namespace edirom="http://www.edirom.de";
declare namespace session="http://exist-db.org/xquery/session";
import module namespace config="https://github.com/peterstadler/odd-validation/modules/config" at "config.xqm";

(:~
 : Create a new session and store request-parameters as default entries
 : Entries are stored in a map object
 :
 : @return The token corresponding to session map
~:)
declare function sess:create-session-map() as xs:string {
    let $request-params := request:get-parameter-names()[. = $config:valid-request-params]
    let $session-ID := (session:invalidate(), session:create(), session:get-id())
    let $map := 
        map:new(
            for $param in $request-params
            return 
                if(ends-with($param, 'File')) then (
                    map:entry($param, sess:parse-upload($param)),
                    map:entry($param || 'Name', request:get-uploaded-file-name($param))
                )
                else ()
                    (:map:entry(
                        $param, request:get-parameter($param, ())
                    ):)
        )
    let $store-session := sess:save-session-map($session-ID , $map)
    return 
        $session-ID cast as xs:string
};

(:~
 : Save the session map into the HTTP session
 : (The main purpose of this wrapper function is that the storage location can easily be changed)
 :
 : @return empty
~:)
declare function sess:save-session-map($token as xs:string, $map as map(*)) as item()* {
    session:set-attribute($token, $map)
};

(:~
 : Get the session map
 :
 : @return The token corresponding to session map
~:)
declare function sess:get-session-map($token as xs:string) as map(*)? {
    session:get-attribute($token)
};

(:~
 : Add an entry to the session map
 :
 : @return The updated session map
~:)
declare function sess:add-entry-to-session-map($token as xs:string, $key as xs:string, $value as item()*) as map(*) {
    let $current-session := sess:get-session-map($token)
    let $map := map:new(($current-session, map:entry($key, $value)))
    let $store := sess:save-session-map($token, $map)
    return 
        $map
};

(:~
 : Helper function for parsing uploaded files
 :
 : @return The updated session map
~:)
declare %private function sess:parse-upload($req-param as xs:string) as node()? {
    let $input := request:get-uploaded-file-data($req-param)
    return
        try { parse-xml(util:binary-to-string($input)) }
        catch * {error(xs:QName('edirom:parser-fail'), 'failed to parse as xml file')}
};
