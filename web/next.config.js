/** @type {import('next').NextConfig} */

const fs = require("fs");
const path = require("path");

function parseDotenvFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, "utf8");
    return Object.fromEntries(
      content
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter((line) => line && !line.startsWith("#") && line.includes("="))
        .map((line) => {
          const idx = line.indexOf("=");
          const key = line.slice(0, idx).trim();
          const value = line
            .slice(idx + 1)
            .trim()
            .replace(/^['"]|['"]$/g, "");
          return [key, value];
        }),
    );
  } catch {
    return {};
  }
}

function firstNonEmpty(...values) {
  for (const value of values) {
    if (value !== undefined && value !== null && String(value).trim() !== "") {
      return String(value).trim();
    }
  }
  return "";
}

function normalizeBoolean(value) {
  return ["1", "true", "yes", "on"].includes(String(value).trim().toLowerCase())
    ? "true"
    : "false";
}

const ROOT_ENV = parseDotenvFile(path.resolve(__dirname, "..", ".env"));
/** Same keys as Next's web/.env* — merged here so Streamlit URLs work when only defined under `web/`. */
const WEB_ENV_FILE = parseDotenvFile(path.resolve(__dirname, ".env"));
const WEB_ENV_LOCAL = parseDotenvFile(path.resolve(__dirname, ".env.local"));

const BACKEND_PORT = firstNonEmpty(
  ROOT_ENV.BACKEND_PORT,
  process.env.BACKEND_PORT,
  "8001",
);

// Use the project-root `.env` as the frontend source of truth. This keeps
// local auth setup to one file: AUTH_ENABLED=true also enables Next middleware.
const NEXT_PUBLIC_API_BASE = firstNonEmpty(
  ROOT_ENV.NEXT_PUBLIC_API_BASE_EXTERNAL,
  process.env.NEXT_PUBLIC_API_BASE_EXTERNAL,
  ROOT_ENV.NEXT_PUBLIC_API_BASE,
  process.env.NEXT_PUBLIC_API_BASE,
  `http://localhost:${BACKEND_PORT}`,
);

const NEXT_PUBLIC_AUTH_ENABLED = normalizeBoolean(
  firstNonEmpty(
    ROOT_ENV.NEXT_PUBLIC_AUTH_ENABLED,
    ROOT_ENV.AUTH_ENABLED,
    process.env.NEXT_PUBLIC_AUTH_ENABLED,
    process.env.AUTH_ENABLED,
    "false",
  ),
);

process.env.NEXT_PUBLIC_API_BASE = NEXT_PUBLIC_API_BASE;
process.env.NEXT_PUBLIC_AUTH_ENABLED = NEXT_PUBLIC_AUTH_ENABLED;

// Optional Streamlit (or other external) auth UI — root `.env`, then `web/.env`, then `web/.env.local`.
const NEXT_PUBLIC_STREAMLIT_APP_URL = firstNonEmpty(
  WEB_ENV_LOCAL.NEXT_PUBLIC_STREAMLIT_APP_URL,
  WEB_ENV_FILE.NEXT_PUBLIC_STREAMLIT_APP_URL,
  ROOT_ENV.NEXT_PUBLIC_STREAMLIT_APP_URL,
  process.env.NEXT_PUBLIC_STREAMLIT_APP_URL,
);
const NEXT_PUBLIC_STREAMLIT_SIGNUP_URL = firstNonEmpty(
  WEB_ENV_LOCAL.NEXT_PUBLIC_STREAMLIT_SIGNUP_URL,
  WEB_ENV_FILE.NEXT_PUBLIC_STREAMLIT_SIGNUP_URL,
  ROOT_ENV.NEXT_PUBLIC_STREAMLIT_SIGNUP_URL,
  process.env.NEXT_PUBLIC_STREAMLIT_SIGNUP_URL,
);
const NEXT_PUBLIC_STREAMLIT_LOGIN_URL = firstNonEmpty(
  WEB_ENV_LOCAL.NEXT_PUBLIC_STREAMLIT_LOGIN_URL,
  WEB_ENV_FILE.NEXT_PUBLIC_STREAMLIT_LOGIN_URL,
  ROOT_ENV.NEXT_PUBLIC_STREAMLIT_LOGIN_URL,
  process.env.NEXT_PUBLIC_STREAMLIT_LOGIN_URL,
);
if (NEXT_PUBLIC_STREAMLIT_APP_URL) {
  process.env.NEXT_PUBLIC_STREAMLIT_APP_URL = NEXT_PUBLIC_STREAMLIT_APP_URL;
}
if (NEXT_PUBLIC_STREAMLIT_SIGNUP_URL) {
  process.env.NEXT_PUBLIC_STREAMLIT_SIGNUP_URL = NEXT_PUBLIC_STREAMLIT_SIGNUP_URL;
}
if (NEXT_PUBLIC_STREAMLIT_LOGIN_URL) {
  process.env.NEXT_PUBLIC_STREAMLIT_LOGIN_URL = NEXT_PUBLIC_STREAMLIT_LOGIN_URL;
}

// Resolve the build-time application version. Priority:
//   1. Explicit APP_VERSION env (set by CI from the release tag)
//   2. `git describe --tags` when building from a checkout (local dev)
//   3. Empty string → frontend treats it as "unknown" and shows the
//      latest GitHub release as a neutral fallback.
const APP_VERSION = (() => {
  if (process.env.APP_VERSION) return process.env.APP_VERSION;
  try {
    const { execSync } = require("child_process");
    return execSync("git describe --tags --always --dirty=-dev", {
      stdio: ["ignore", "pipe", "ignore"],
    })
      .toString()
      .trim();
  } catch {
    return "";
  }
})();

const nextConfig = {
  // Expose the build-time version to the browser so the sidebar badge
  // can compare it against GitHub's latest release.
  env: {
    NEXT_PUBLIC_APP_VERSION: APP_VERSION,
    NEXT_PUBLIC_API_BASE,
    NEXT_PUBLIC_AUTH_ENABLED,
    // Always define keys so client + middleware bundles replace literals reliably.
    NEXT_PUBLIC_STREAMLIT_APP_URL: NEXT_PUBLIC_STREAMLIT_APP_URL || "",
    NEXT_PUBLIC_STREAMLIT_SIGNUP_URL: NEXT_PUBLIC_STREAMLIT_SIGNUP_URL || "",
    NEXT_PUBLIC_STREAMLIT_LOGIN_URL: NEXT_PUBLIC_STREAMLIT_LOGIN_URL || "",
  },

  // Standalone output: self-contained server.js + minimal node_modules
  // This eliminates the need to copy the full node_modules into Docker production images
  output: "standalone",

  // Move dev indicator to bottom-right corner
  devIndicators: {
    position: "bottom-right",
  },

  // Transpile mermaid and related packages for proper ESM handling
  transpilePackages: ["mermaid"],

  // Enable SWR caching for better performance
  swcMinify: true,

  // Optimize images
  images: {
    optimization: {
      formats: ['image/avif', 'image/webp'],
    },
  },

  // Production optimizations
  productionBrowserSourceMaps: false,

  // Compression and minification
  compress: true,

  // Turbopack configuration (used when running `npm run dev:turbo`)
  turbopack: {
    resolveAlias: {
      // Fix for mermaid's cytoscape dependency - use CJS version
      cytoscape: "cytoscape/dist/cytoscape.cjs.js",
    },
  },

  // Webpack configuration (used for production builds - next build)
  webpack: (config, { isServer }) => {
    const path = require("path");
    config.resolve.alias = {
      ...config.resolve.alias,
      cytoscape: path.resolve(
        __dirname,
        "node_modules/cytoscape/dist/cytoscape.cjs.js",
      ),
    };

    // Add bundlesize optimization
    if (!isServer) {
      config.optimization = {
        ...config.optimization,
        usedExports: true,
      };
    }

    return config;
  },
};

module.exports = nextConfig;
