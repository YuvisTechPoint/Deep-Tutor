/**
 * IndexedDB queue for POST mutations when the browser is offline (blueprint ch 24).
 * Flushed on `online` + manual `flushOfflineQueue()`.
 */

import { apiFetch, apiUrl } from "@/lib/api";

const DB_NAME = "deeptutor-offline-v1";
const STORE = "mutations";
const DB_VERSION = 1;

export class OfflineQueuedError extends Error {
  readonly kind: string;

  constructor(kind: string, message = "OFFLINE_QUEUED") {
    super(message);
    this.name = "OfflineQueuedError";
    this.kind = kind;
  }
}

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onerror = () => reject(req.error);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE)) {
        db.createObjectStore(STORE, { keyPath: "id", autoIncrement: true });
      }
    };
    req.onsuccess = () => resolve(req.result);
  });
}

export async function enqueueOfflineMutation(
  method: "POST",
  path: string,
  body: unknown,
): Promise<void> {
  const db = await openDb();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.objectStore(STORE).add({
      method,
      path,
      body_json: JSON.stringify(body ?? {}),
      created_at: Date.now(),
    });
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
  db.close();
}

export async function pendingOfflineCount(): Promise<number> {
  const db = await openDb();
  const n = await new Promise<number>((resolve, reject) => {
    const tx = db.transaction(STORE, "readonly");
    const req = tx.objectStore(STORE).count();
    req.onsuccess = () => resolve(Number(req.result));
    req.onerror = () => reject(req.error);
  });
  db.close();
  return n;
}

/** POST queued mutations; server wins on conflict. Removes successful rows. */
export async function flushOfflineQueue(): Promise<{ sent: number; failed: number }> {
  if (typeof navigator !== "undefined" && !navigator.onLine) {
    return { sent: 0, failed: 0 };
  }
  const db = await openDb();
  const rows: { id: number; path: string; body_json: string }[] = await new Promise(
    (resolve, reject) => {
      const out: { id: number; path: string; body_json: string }[] = [];
      const tx = db.transaction(STORE, "readonly");
      const cur = tx.objectStore(STORE).openCursor();
      cur.onsuccess = () => {
        const c = cur.result;
        if (!c) {
          resolve(out);
          return;
        }
        const v = c.value as { id: number; path: string; body_json: string };
        out.push(v);
        c.continue();
      };
      cur.onerror = () => reject(cur.error);
    },
  );

  let sent = 0;
  let failed = 0;
  for (const row of rows) {
    try {
      const res = await apiFetch(apiUrl(row.path), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: row.body_json,
      });
      if (!res.ok) {
        failed += 1;
        continue;
      }
      await new Promise<void>((resolve, reject) => {
        const tx = db.transaction(STORE, "readwrite");
        tx.objectStore(STORE).delete(row.id);
        tx.oncomplete = () => resolve();
        tx.onerror = () => reject(tx.error);
      });
      sent += 1;
    } catch {
      failed += 1;
    }
  }
  db.close();
  return { sent, failed };
}
