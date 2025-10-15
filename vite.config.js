import { defineConfig } from "vite";
import { NodeGlobalsPolyfillPlugin } from "@esbuild-plugins/node-globals-polyfill";

export default defineConfig({
    root: ".",
    build: {
        outDir: "dist",
    },
    resolve: {
        alias: {
            crypto: "crypto-browserify",
            stream: "stream-browserify",
            os: "os-browserify",
            vm: "vm-browserify",
            path: "path-browserify",
            buffer: "buffer",
            process: "process/browser",
        },
    },
    define: {
        global: "window",
        "process.env": {},
    },
    optimizeDeps: {
        esbuildOptions: {
            plugins: [NodeGlobalsPolyfillPlugin({ buffer: true })],
        },
    },
});
