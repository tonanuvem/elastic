FROM node:8

WORKDIR /usr/src/app
COPY package*.json ./

RUN mkdir -p /app
RUN npm install express
RUN npm install elastic-apm-node

COPY . .
COPY ./64aoj_arquivos/* ./64aoj_arquivos/
EXPOSE 3000
CMD [ "npm", "start" ]
