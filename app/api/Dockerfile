FROM node:20-alpine

WORKDIR /app

# Install production dependencies first
COPY package*.json ./
RUN npm install --omit=dev --no-audit --no-fund \
    && npm cache clean --force \
    && rm -rf /root/.npm /usr/local/share/.cache /opt/yarn* /usr/local/bin/yarn*

# Copy application code
COPY . .

# Use non-root Node user
USER node

EXPOSE 3000

HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=5 \
    CMD node -e "fetch('http://127.0.0.1:3000/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["npm", "start"]
