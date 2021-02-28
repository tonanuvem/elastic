# Diretorio com arquivos usados em outros labs.

## Branch com os diversos arquivos.

git checkout files

## Dados de log do arquivo : "ufw.log"

O log de firewall que foi gravado de uma máquina virtual criada na digital ocean. Os dados do período de aproximadamente 12/02/2019 a 18/02/2019. Para manter o interesse dos invasores, serviços de honeypot de baixa interação foram configurados em várias portas. O tráfego para a porta 2222 deve ser ignorado, pois o honeypot foi administrado por meio dessa porta. O tráfego de saída do próprio honeypot está presente nos dados, portanto, se  deseja filtrar o tráfego de saída, remova source_ip: 104.248.50.195 das visualizações.

# Intrusion detection in real time Network Log Data (ELK as SIEM)

## Fonte:

- Compose atualizado para as últimas versões Kibana e ElasticSearch

- https://github.com/asadmanzoor93/elk-siem

- https://github.com/AICoE/log-anomaly-detector

## Elatic repo:

- https://github.com/elastic/examples/tree/master/Machine%20Learning/Security%20Analytics%20Recipes

- https://www.elastic.co/guide/en/siem/guide/current/siem-overview.html

- https://www.elastic.co/pt/blog/machine-learning-for-nginx-logs

## Logstash parse log example:

- https://coralogix.com/log-analytics-blog/logstash-grok-tutorial-with-examples/

## Configs

### Config: "Override settings"

```%{SYSLOGBASE} \[%{DATA}\] \[%{DATA:action}\] IN=(%{WORD:in})? OUT=(%{WORD:out})?( MAC=%{DATA:mac})? SRC=%{IP:source_ip} DST=%{IP:destination_ip} %{DATA} PROTO=%{WORD:protocol}( SPT=%{INT:source_port} DPT=%{INT:destination_port})?```

### Config: "Advanced settings"

Type the name `ufw_logs` in the "Index name" field

Place the following in the **mappings** window:
```
{
  "properties": {
    "@timestamp": {
      "type": "date"
    },
    "action": {
      "type": "keyword"
    },
    "destination_ip": {
      "type": "ip"
    },
    "destination_port": {
      "type": "long"
    },
    "in": {
      "type": "keyword"
    },
    "logsource": {
      "type": "keyword"
    },
    "mac": {
      "type": "keyword"
    },
    "message": {
      "type": "text"
    },
    "out": {
      "type": "keyword"
    },
    "program": {
      "type": "keyword"
    },
    "protocol": {
      "type": "keyword"
    },
    "source_ip": {
      "type": "ip"
    },
    "source_port": {
      "type": "long"
    },
    "geoip": {
      "properties": {
        "location": { "type": "geo_point" }
      }
    }
  }
}
```


Place the following in the ingest pipeline window:
```
{
  "description": "Ingest pipeline created by file structure finder",
  "processors": [
    {
      "grok": {
        "field": "message",
        "patterns": [
          "%{SYSLOGBASE} \\[%{DATA}\\] \\[%{DATA:action}\\] IN=(%{WORD:in})? OUT=(%{WORD:out})?( MAC=%{DATA:mac})? SRC=%{IP:source_ip} DST=%{IP:destination_ip} %{DATA} PROTO=%{WORD:protocol}( SPT=%{INT:source_port} DPT=%{INT:destination_port})?"
        ]
      }
    },
    {
      "date": {
        "field": "timestamp",
        "timezone": "{{ event.timezone }}",
        "formats": [
          "MMM dd HH:mm:ss",
          "MMM  d HH:mm:ss",
          "MMM d HH:mm:ss"
        ]
      }
    },
    {
      "remove": {
        "field": "timestamp"
      }
    },
    {
      "geoip": {
        "field" : "source_ip"
      }
    }
  ]
}
```
