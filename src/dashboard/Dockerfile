FROM node:18-alpine

WORKDIR /app
COPY src/dashboard/package*.json ./
RUN npm install

COPY src/dashboard /app
CMD ["npm", "start"]
