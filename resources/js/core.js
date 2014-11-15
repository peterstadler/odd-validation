$( document ).ready(function() {
    /* Hide everything initially */
    hideEverything();
    
    $('button#submit').click(function(){
        hideEverything();
        validateForm(upload);
        //console.log(document.getElementById('xmlFile'));
    });
});

function hideEverything() {
    $('#results,#results ul,#results li').hide();
}

function validateForm(callback) {
    if($('#xmlFile')[0].files.length === 1) {callback(runTest)}
    else {alert('please enter a file')}
}

function getLatestTEIVersion() {
    return '2.7.0'
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

function runTest(token) {
    //console.log('call tests for token: ' + token + '!');
    var task = 'list-element-namespaces';
    var testData = {'task': task, 'format': 'json', 'token': token};
    $('#results .tei-version').html('TEI version ' + getLatestTEIVersion());
    $('#results .' + 'tei-validate' + ' li:first').show();
    $('#results .ajax-spinner').show();
    $('#results .' + 'tei-validate').show();
    $('#results').show();
    callTest(testData, successFunction_listNamespaces);
}

function successFunction_listNamespaces(msg) {
    var testData = {'task': 'tei-validate', 'version': '2.7.0', 'format': 'json', 'token': msg.properties.token, 'externalNS': msg.properties.externalNS};
    $('#results .fileName').html(msg.properties.xmlFileName);
    if(msg.properties.externalNS === 'true') {$('#results .externalNS').show()};
    callTest(testData, successFunction_teiValidate);
}

function successFunction_teiValidate(msg) {
    $('#results .rootElement').html('&lt;' + msg.properties.rootElement + '&gt;');
    if(msg.properties.fragment === 'true') {$('#results .fragment').show()};
    
    $('#results .ajax-spinner').hide();
    if(msg.results.status === 'valid' && msg.properties.fragment === 'false' && msg.properties.externalNS === 'false') {$('#results .conformant').show()}
    else if(msg.results.status === 'invalid') {$('#results .invalid').show()}
    else {$('#results .conformable').show()}
    //$('#results .' + task).show();
}

function callTest(data, successFunction) {
    $.ajax({
        url: 'results.xql',
        type: "GET",
        data: data,
        cache: false,
        success: function(msg){
            //console.log(msg);
            successFunction(msg);
        }
    });
}

function upload(callback) {
    var xmlFileInput = document.getElementById('xmlFile');
    var xmlFile = xmlFileInput.files[0];
    var formData = new FormData();
    formData.append('xmlFile', xmlFile);
    formData.append('task', 'init');
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