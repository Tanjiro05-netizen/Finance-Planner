FROM node:20-bookworm-slim

WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json ./
COPY prisma ./prisma
RUN npm ci

COPY . .

EXPOSE 3000
CMD ["sh", "-c", "npm run db:migrate && npm start"]
