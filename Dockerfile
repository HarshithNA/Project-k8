FROM node:18-alpine

WORKDIR /app

COPY app/package.json .
RUN npm install --production

COPY app/ .

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -qO- http://localhost:8080/health || exit 1

CMD ["node", "index.js"]
EOF
