FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
RUN mkdir -p data uploads && chown -R node:node /app
USER node
EXPOSE 3000
VOLUME ["/app/data", "/app/uploads"]
CMD ["node", "src/server.js"]
