$( document ).ready(function() {
    /* Hide everything initially */
    hideEverything();
    
    $('button#submit').click(function(){
        hideEverything();
        validateForm(init);
    });
});


function hideEverything() {
    $('#results,#results ul,#results li').hide();
}


function validateForm(callback) {
    if($('#xmlFile')[0].files.length === 1) {callback(successFunction_init)}
    else {alert('please enter a file')}
}


function getLatestTEIVersion() {
    // TODO
    return '2.7.0'
}


function successFunction_init(msg) {
    var testData = {
        'task': 'list-element-namespaces', 
        'format': 'json', 
        'token': msg.results.sessionID
    };
    
    // Replace placeholder
    $('#results .fileName').html(msg.properties.xmlFileName);
    $('#results .rootElement').html('&lt;' + msg.results.rootElement + '&gt;');
    
    if(msg.results.supportedFileFormat === 'true') {
        $('#results .tei-version').html('TEI version ' + getLatestTEIVersion());
        $('#results .' + 'tei-validate' + ' li:first').show();
        $('#results .ajax-spinner').show();
        $('#results .' + 'tei-validate').show();
        callTest(testData, successFunction_listNamespaces);
    }
    else {
        $('#results .unsupportedFileFormat').show();
        $('#results .errors').show();
    }
    $('#results').show();
}


function successFunction_listNamespaces(msg) {
    var testData = {
        'task': 'tei-validate', 
        'version': getLatestTEIVersion(), 
        'format': 'json', 
        'token': msg.properties.token, 
        'externalNS': msg.properties.externalNS
    };
    if(msg.properties.externalNS === 'true') {$('#results .externalNS').show()};
    callTest(testData, successFunction_teiValidate);
}


function successFunction_teiValidate(msg) {
    if(msg.properties.fragment === 'true') {$('#results .fragment').show()};
    
    $('#results .ajax-spinner').hide();
    if(msg.results.status === 'valid' && msg.properties.fragment === 'false' && msg.properties.externalNS === 'false') {$('#results .conformant').show()}
    
    else if(msg.properties.oddFile === 'true') {
        $('#results .oddFile').show();
        $('#results .ajax-spinner').show();
        var testData = {
            'task': 'odd-validate', 
            'format': 'json', 
            'token': msg.properties.token,
            'version': msg.properties.version,
            'fragment': msg.properties.fragment,
            'externalNS': msg.properties.externalNS
        };
        callTest(testData, successFunction_oddValidate);
    }
    else if(msg.results.status === 'invalid') {$('#results .invalid').show()}
    else {$('#results .conformable').show()};
}


function successFunction_oddValidate(msg) {
    $('#results .ajax-spinner').hide();
    if(msg.results.status === 'invalid') {$('#results .invalid').show()}
    else {$('#results .conformable').show()};
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


function init(successFunction) {
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
            successFunction(msg);
        }
    });
};
