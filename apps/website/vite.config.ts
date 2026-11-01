import { defineConfig } from "vite";
import { readFileSync } from "node:fs";

export default defineConfig({
  base: process.env.WAYDAY_BASE_PATH || "/Wayday/",
  define: {
    __WAYDAY_RELEASE_DATA__: JSON.stringify(
      JSON.parse(
        readFileSync(
          process.env.WAYDAY_RELEASE_FILE ||
            new URL("./src/release-data.json", import.meta.url),
          "utf8",
        ),
      ),
    ),
  },
});
