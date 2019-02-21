'use strict'

var apm = require('elastic-apm-node').start({
  frameworkName: 'express',
  frameworkVersion: 'unknown',
  serviceName: 'aplicacao-fiap-nodejs-v2',
  serverUrl: 'http://apm-server:8200',
  flushInterval: 1,
  maxQueueSize: 1,
  apiRequestTime: "50ms",
  ignoreUrls: ['/healthcheck']
})

var express = require('express');
var app = express();
var fs = require('fs');
var path = require('path');

app.use("/64aoj_arquivos", express.static(path.resolve(__dirname, '64aoj_arquivos')));

app.get("/", function(req, res) {
  fs.readFile('index.html', function(err, data) {
    res.writeHead(200, {'Content-Type': 'text/html'});
    res.write(data);
    res.end();
  });
});

app.get("/healthcheck", function(req, res) {
    res.send("OK: " + path.resolve(__dirname, '64aoj_arquivos'));
    app.use("/64aoj_arquivos", express.static(path.resolve(__dirname, '64aoj_arquivos')));
});

app.get("/aoj", function(req, res) {
  apm_route()
  fs.readFile('64aoj.htm', function(err, data) {
    res.writeHead(200, {'Content-Type': 'text/html'});
    res.write(data);
    res.end();
  });
});

function apm_route () {
    var span = apm.startSpan('app.fiap', 'custom')
    span.end()
}

app.get("/bar", function(req, res) {
  bar_route()
  fs.readFile('bar.html', function(err, data) {
    res.writeHead(200, {'Content-Type': 'text/html'});
    res.write(data);
    res.end();
  });
});

function bar_route () {
    var span = apm.startSpan('app.bar', 'custom')
    extra_route()
    span.end()
}

function extra_route () {
    var span = apm.startSpan('app.extra', 'custom')
    span.end()
}

app.get("/erro", function(req, res, next) {
    next(new Error("Error aconteceu"));
});

app.use(function (err, req, res, next) {
  console.error(err.stack)
  res.status(500).send('Something broke!')
});

var server = app.listen('3000', '0.0.0.0', function () {
    console.log("Listening on %s...", server.address().port);
});
