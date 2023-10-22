// Development web server

var cgi = require('cgi')
var http = require('http')
var path = require('path')

// Make a sanitized environment to keep perl -T happy
for (const v of ['PATH', 'IFS', 'CDPATH', 'ENV', 'BASH_ENV']) {
    delete process.env[v]
}

var script = path.resolve(__dirname, 'web.pl')
process.chdir(path.dirname(script))
var server = http.createServer(cgi(script, { stderr: process.stderr }))
server.listen(
    0,
    (x) => console.log(`Connect to server at: http://localhost:${server.address().port}`)
)
