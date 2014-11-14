$( document ).ready(function() {
    /* Hide everything initially */
    hideEverything();
    
    $('button#submit').click(function(){
        hideEverything();
        upload(test);
    });
});

function hideEverything() {
    $('#results,#results ul,#results li').hide();
}

/*
function getJSessionId(){
    var jsId = document.cookie.match(/JSESSIONID=[^;]+/);
    if(jsId != null) {
        if (jsId instanceof Array)
            jsId = jsId[0].substring(11);
        else
            jsId = jsId.substring(11);
    }
    return jsId;
};
*/

function test(token) {
    //console.log('call tests for token: ' + token + '!');
    
    //callTest(token, 'tei-all');
    //callTest(token, 'tei-lite');
    var version = '2.7.0';
    var task = 'tei-validate';
    //var displayVersion = (version === 'current')? '2.7.0': version;
    $('#results .tei-version').html('TEI version ' + version);
    $('#results .' + task + ' li:first').show();
    $('#results .ajax-spinner').show();
    $('#results .' + task).show();
    $('#results').show();
    callTest(token, task, version);
}

function callTest(token, task, version) {
    $.ajax({
        url: 'results.xql',
        type: "GET",
        data: {'task': task, 'version': version, 'format': 'json'},
        cache: false,
        success: function(msg){
            //console.log(msg);
            $('#results .fileName').html(msg.properties.xmlFileName);
            $('#results .rootElement').html('&lt;' + msg.properties.rootElement + '&gt;');
            if(msg.properties.fragment === 'true') {$('#results .fragment').show()};
            if(msg.properties.externalNS === 'true') {$('#results .externalNS').show()};
            
            $('#results .ajax-spinner').hide();
            if(msg.results.status === 'valid' && msg.properties.fragment === 'false' && msg.properties.externalNS === 'false') {$('#results .conformant').show()}
            else if(msg.results.status === 'invalid') {$('#results .invalid').show()}
            else {$('#results .conformable').show()}
            
            //$('#results .' + task).show();
        }
    });
}

function upload(callback) {
    var xmlFileInput = document.getElementById('xmlFile');
    var xmlFile = xmlFileInput.files[0];
    var formData = new FormData();
    formData.append('xmlFile', xmlFile);
    formData.append('task', 'upload');
    formData.append('format', 'json');
/*    formData.append('xml-url', $('#xml-url')[0].value);*/
/*    formData.append('version', $('#tei-version option:selected')[0].value);*/

    $.ajax({
        url: 'results.xql',
        //"http://posttestserver.com/post.php",
        type: "POST",
        //mimeType: "multipart/form-data",
        data: formData,
        cache: false,
        processData: false,
        contentType: false, 
        //'multipart/form-data',
        
        success: function(msg){
            var token = msg.sessionID;
            //console.log(token);
            callback(token);
        }
    });
};