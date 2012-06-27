var app = require('http').createServer(handler)
	,io=require('socket.io').listen(app)
	,fs=require('fs')
	,url=require('url')
	,path=require('path');

app.listen(8081);

function handler(request,response) {
console.log('request starting... 8081');
     
    var filePath = '.' + request.url;
    if (filePath == './')
        filePath = './index.html';
     
    path.exists(filePath, function(exists) {
     
        if (exists) {
            fs.readFile(filePath, function(error, content) {
                if (error) {
                    response.writeHead(500);
                    response.end();
                }
                else {
                    response.writeHead(200);
                    response.end(content, 'utf-8');
                }
            });
        }
        else {
            response.writeHead(404);
            response.end();
        }
    });
	}

