const http = require('http');
const fs = require('fs');

const server = http.createServer((req, res) => {
    if (req.method === 'POST') {
        let body = [];
        req.on('data', chunk => {
            body.push(chunk);
        }).on('end', () => {
            body = Buffer.concat(body);
            fs.writeFileSync('github_action.log', body);
            res.writeHead(200);
            res.end('OK');
            console.log('Received log! Exiting...');
            process.exit(0);
        });
    } else {
        res.writeHead(404);
        res.end();
    }
});

server.listen(8081, '127.0.0.1', () => {
    console.log('Listening on 8081...');
});
