FROM node:22-alpine AS base
RUN corepack enable && corepack prepare pnpm@latest --activate
WORKDIR /app

# Install deps
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Copy source
COPY . .

# Dev mode
EXPOSE 6006
CMD ["pnpm", "storybook", "--ci", "--no-open", "--host", "0.0.0.0"]
