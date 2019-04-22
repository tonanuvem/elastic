FROM node:8

WORKDIR /usr/src/app
COPY package*.json ./

RUN mkdir -p /app
RUN npm install express
RUN npm install elastic-apm-node

COPY . .
COPY ./26ati_arquivos/* ./26ati_arquivos/

EXPOSE 3000
CMD [ "npm", "start" ]
