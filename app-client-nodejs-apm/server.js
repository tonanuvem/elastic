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


const winston = require('winston')
const ecsFormat = require('@elastic/ecs-winston-format')

const logger = winston.createLogger({
  //level: 'debug',
  level: 'info',
  format: ecsFormat({ convertReqRes: true }),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({
      //path to log file
      filename: 'logs/log.json',
      level: 'debug'
    })
  ]
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
    logger.info('fiap healthcheck: Solicitação de saúde da aplicação', { req, res })
});

app.get("/fiap", function(req, res) {
  logger.info('fiap endpoint: Solicitação de página sobre kahoot', { req, res })
  fs.readFile('fiap.htm', function(err, data) {
    res.writeHead(200, {'Content-Type': 'text/html'});
    res.write(data);
    res.end();
  });
});

app.get("/bar", function(req, res) {
  logger.info('fiap bar: Solicitação de bebida na página bar', { req, res })
  bar_route()
  fs.readFile('bar.html', function(err, data) {
    res.writeHead(200, {'Content-Type': 'text/html'});
    res.write(data);
    res.end();
  });
});

function bar_route () {
    logger.info('fiap bar rota: Solicitação de rota para o bar', { req, res })
    var span = apm.startSpan('app.bar.Cerveja_acabou', 'custom')
    extra_route()
    span.end()
}

function extra_route () {
    logger.info('fiap bar rota extra: Solicitação de rota extra para o bar', { req, res })
    var span = apm.startSpan('app.extra.pegar_no_Vizinho', 'custom')
    span.end()
}

app.get("/erro", function(req, res, next) {
    logger.error('ERRO: aconteceu algo inesperado', { req, res })
    next(new Error("Um Erro aconteceu"));
});

app.use(function (err, req, res, next) {
  console.error(err.stack)
  res.status(500).send('EITAAAA.... DEU RUIM!')
});

var server = app.listen('3000', '0.0.0.0', function () {
    logger.info("Started app fiap");
});
