import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Gọi API qua proxy của dev server để khỏi cấu hình CORS ở backend.
// Trong docker compose đặt BACKEND_URL=http://backend:8000, AI_SERVICE_URL=http://ai-service:8001.
const backendUrl = process.env.BACKEND_URL ?? "http://localhost:8000";
const aiServiceUrl = process.env.AI_SERVICE_URL ?? "http://localhost:8001";

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      "/api/backend": { target: backendUrl, changeOrigin: true, rewrite: (path) => path.replace(/^\/api\/backend/, "") },
      "/api/ai": { target: aiServiceUrl, changeOrigin: true, rewrite: (path) => path.replace(/^\/api\/ai/, "") },
    },
  },
});
