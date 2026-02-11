FROM node:22

WORKDIR /usr/src/app
COPY package.json ./
RUN npm install --save --silent
COPY . .
COPY ./shift/* ./shift/
RUN mkdir -p logs

EXPOSE 3000
CMD [ "npm", "start" ]
