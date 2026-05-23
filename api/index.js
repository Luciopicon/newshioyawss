import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { setDefaultResultOrder } from "node:dns";

export const config = {
  api: { bodyParser: false },
  supportsResponseStreaming: true,
  maxDuration: 60,
};

// DOMÍNIO FIXO
const TARGET_BASE = "https://br.newshioya.shop";

// DNS
const UPSTREAM_DNS_ORDER = "ipv4first";

// TIMEOUT
const UPSTREAM_TIMEOUT_MS = 60000;

// LIMITE DE REQUESTS
const MAX_INFLIGHT = 128;

// HEADERS
const PLATFORM_HEADER_PREFIX = `x-${String.fromCharCode(
  118,
  101,
  114,
  99,
  101,
  108
)}-`;

const ALLOWED_METHODS = new Set([
  "GET",
  "HEAD",
  "POST",
  "PUT",
  "PATCH",
  "DELETE",
  "OPTIONS"
]);

const FORWARD_HEADER_EXACT = new Set([
  "accept",
  "accept-encoding",
  "accept-language",
  "authorization",
  "cache-control",
  "content-length",
  "content-type",
  "cookie",
  "pragma",
  "range",
  "referer",
  "origin",
  "user-agent"
]);

const FORWARD_HEADER_PREFIXES = [
  "sec-ch-",
  "sec-fetch-"
];

const STRIP_HEADERS = new Set([
  "host",
  "connection",
  "proxy-connection",
  "keep-alive",
  "via",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailer",
  "transfer-encoding",
  "upgrade",
  "forwarded",
  "x-forwarded-host",
  "x-forwarded-proto",
  "x-forwarded-port"
]);

let inFlight = 0;

applyDnsPreference();

export default async function handler(req, res) {
  let slotAcquired = false;

  try {
    const host = req.headers.host || "localhost";

    const url = new URL(
      req.url || "/",
      `https://${host}`
    );

    // IGUAL:
    // https://br.newshioya.shop/$1
    const targetUrl =
      `${TARGET_BASE}${url.pathname}${url.search || ""}`;

    if (!ALLOWED_METHODS.has(req.method)) {
      res.statusCode = 405;
      res.setHeader(
        "allow",
        "GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS"
      );

      return res.end("Method Not Allowed");
    }

    if (!tryAcquireSlot()) {
      res.statusCode = 503;
      return res.end("Server Busy");
    }

    slotAcquired = true;

    const headers = {};

    for (const key of Object.keys(req.headers)) {
      const lower = key.toLowerCase();
      const value = req.headers[key];

      if (STRIP_HEADERS.has(lower)) {
        continue;
      }

      if (lower.startsWith(PLATFORM_HEADER_PREFIX)) {
        continue;
      }

      if (!shouldForwardHeader(lower)) {
        continue;
      }

      const normalizedValue = toHeaderValue(value);

      if (normalizedValue) {
        headers[lower] = normalizedValue;
      }
    }

    const hasBody =
      req.method !== "GET" &&
      req.method !== "HEAD";

    const abortCtrl = new AbortController();

    const timeoutRef = setTimeout(() => {
      try {
        abortCtrl.abort();
      } catch {}
    }, UPSTREAM_TIMEOUT_MS);

    try {
      const fetchOpts = {
        method: req.method,
        headers,
        redirect: "manual",
        signal: abortCtrl.signal
      };

      if (hasBody) {
        fetchOpts.body = Readable.toWeb(req);
        fetchOpts.duplex = "half";
      }

      const upstream = await fetch(
        targetUrl,
        fetchOpts
      );

      res.statusCode = upstream.status;

      for (const [headerName, headerValue] of upstream.headers) {
        const lower = headerName.toLowerCase();

        if (
          lower === "transfer-encoding" ||
          lower === "connection"
        ) {
          continue;
        }

        try {
          res.setHeader(
            headerName,
            headerValue
          );
        } catch {}
      }

      if (!upstream.body) {
        return res.end();
      }

      const upstreamNode =
        Readable.fromWeb(upstream.body);

      await pipeline(
        upstreamNode,
        res
      );
    } finally {
      clearTimeout(timeoutRef);
    }
  } catch (err) {
    console.error("proxy error:", err);

    if (!res.headersSent) {
      res.statusCode = 502;
      return res.end("Bad Gateway");
    }
  } finally {
    if (slotAcquired) {
      releaseSlot();
    }
  }
}

function shouldForwardHeader(headerName) {
  if (FORWARD_HEADER_EXACT.has(headerName)) {
    return true;
  }

  for (const prefix of FORWARD_HEADER_PREFIXES) {
    if (headerName.startsWith(prefix)) {
      return true;
    }
  }

  return false;
}

function applyDnsPreference() {
  try {
    setDefaultResultOrder(
      UPSTREAM_DNS_ORDER
    );
  } catch {}
}

function toHeaderValue(value) {
  if (!value) {
    return "";
  }

  return Array.isArray(value)
    ? value.join(", ")
    : String(value);
}

function tryAcquireSlot() {
  if (inFlight >= MAX_INFLIGHT) {
    return false;
  }

  inFlight += 1;

  return true;
}

function releaseSlot() {
  inFlight = Math.max(
    0,
    inFlight - 1
  );
}
