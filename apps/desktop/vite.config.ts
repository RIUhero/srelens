import path from "node:path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

// @tauri-apps/cli drives this; fixed port so tauri.conf.json devUrl matches.
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: { alias: { "@": path.resolve(__dirname, "./src") } },
  clearScreen: false,
  server: {
    port: 1450,
    strictPort: true,
    watch: { ignored: ["**/coverage/**", "**/dist/**", "**/src-tauri/**"] },
  },
  build: {
    outDir: "dist",
    target: "es2021",
    rollupOptions: {
      output: {
        // Keep stable framework libraries out of the application entry chunk.
        // This is intentionally explicit: a catch-all node_modules split can
        // create opaque circular chunks and make upstream dependency changes
        // harder to review.
        manualChunks(id) {
          if (!id.includes("node_modules")) return undefined;
          if (id.includes("/react/") || id.includes("/react-dom/") || id.includes("/scheduler/")) {
            return "vendor-react";
          }
          if (id.includes("/radix-ui/") || id.includes("/@radix-ui/")) return "vendor-radix";
          if (id.includes("/mobx/") || id.includes("/mobx-react/")) return "vendor-mobx";
          if (id.includes("/lucide-react/")) return "vendor-icons";
          if (id.includes("/yaml/")) return "vendor-yaml";
          return undefined;
        },
      },
    },
  },
});
