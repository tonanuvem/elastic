FROM node:22-alpine

WORKDIR /usr/src/app
COPY package.json ./
RUN npm install -g --silent
COPY . .
COPY ./shift/* ./shift/

EXPOSE 3000
CMD [ "npm", "start" ]
