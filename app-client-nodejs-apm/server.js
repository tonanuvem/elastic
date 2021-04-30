'use strict'

// Verifica se há variável de ambiente 
var APM = process.env.APM ? process.env.APM : "apm-server"

var apm = require('elastic-apm-node').start({
  frameworkName: 'express',
  frameworkVersion: '4.16.1',
  serviceName: 'aplicacao-fiap-nodejs-v2',
//  serverUrl: 'http://apm-server:8200',
  serverUrl: 'http://'+APM+':8200',
  flushInterval: 1,
  maxQueueSize: 1,
  apiRequestTime: "50ms",
//  ignoreUrls: ['/healthcheck']
})

var express = require('express');
var app = express();
var fs = require('fs');
var path = require('path');

app.use("/fiap/shift", express.static(path.resolve(__dirname, 'shift')));

app.get("/", function(req, res) {
  fs.readFile('index.html', function(err, data) {
    res.writeHead(200, {'Content-Type': 'text/html'});
    res.write(data);
    res.end();
  });
});

app.get("/healthcheck", function(req, res) {
    res.send("OK: " + path.resolve(__dirname, 'shift'));
    app.use("/shift", express.static(path.resolve(__dirname, 'shift')));
});

app.get("/fiap", function(req, res) {
  fs.readFile('fiap.htm', function(err, data) {
    res.writeHead(200, {'Content-Type': 'text/html'});
    res.write(data);
    res.end();
  });
});

app.get("/bar", function(req, res) {
  bar_route()
  fs.readFile('bar.html', function(err, data) {
    res.writeHead(200, {'Content-Type': 'text/html'});
    res.write(data);
    res.end();
  });
});

function bar_route () {
    var span = apm.startSpan('app.bar.Cerveja_acabou', 'custom')
    extra_route()
    span.end()
}

function extra_route () {
    var span = apm.startSpan('app.extra.pegar_no_Vizinho', 'custom')
    span.end()
}

app.get("/erro", function(req, res, next) {
    next(new Error("Um Erro aconteceu"));
});

app.use(function (err, req, res, next) {
  console.error(err.stack)
  res.status(500).send('EITAAAA.... DEU RUIM!')
});

var server = app.listen('3000', '0.0.0.0', function () {
    console.log("Listening on %s...", server.address().port);
});
