import { EventEmitter } from 'node:events';
import pg from 'pg';
import type { Logger } from '../lib/logger.js';

export const CONTENT_CHANNEL = 'content_changed';

export interface ContentListenerOptions {
  connectionString: string;
  logger: Logger;
  /**
   * The schema's triggers NOTIFY once per content *statement*, so one transaction delivers a burst of
   * notifications at commit. They are coalesced into a single `change` event carrying the latest version.
   */
  coalesceMs?: number;
  reconnectDelaysMs?: number[];
}

/**
 * One shared LISTEN connection for all SSE clients (SPEC §6.2). Emits `change(version)` after each
 * coalesced burst. Reconnects automatically with backoff; after a reconnect it re-reads the current
 * version so changes made while disconnected are not missed.
 */
export class ContentListener extends EventEmitter<{ change: [version: number] }> {
  private client: pg.Client | null = null;
  private stopped = false;
  private attempt = 0;
  private reconnectTimer: NodeJS.Timeout | null = null;
  private coalesceTimer: NodeJS.Timeout | null = null;
  private pendingVersion: number | null = null;
  private lastEmitted = 0;
  private readonly coalesceMs: number;
  private readonly delays: number[];

  constructor(private readonly options: ContentListenerOptions) {
    super();
    this.coalesceMs = options.coalesceMs ?? 150;
    this.delays = options.reconnectDelaysMs ?? [1000, 2000, 5000, 10_000, 30_000];
  }

  /** Last version known to the listener (0 until connected). */
  get version(): number {
    return Math.max(this.lastEmitted, this.pendingVersion ?? 0);
  }

  async start(): Promise<void> {
    this.stopped = false;
    await this.connect();
  }

  private async connect(): Promise<void> {
    if (this.stopped) return;
    const client = new pg.Client({ connectionString: this.options.connectionString });
    client.on('notification', (msg) => {
      if (msg.channel !== CONTENT_CHANNEL) return;
      const version = Number(msg.payload);
      if (Number.isFinite(version)) this.queue(version);
    });
    client.on('error', (err) => {
      this.options.logger.warn({ err: { message: err.message } }, 'content listener error');
      this.scheduleReconnect(client);
    });
    client.on('end', () => this.scheduleReconnect(client));
    try {
      await client.connect();
      await client.query(`LISTEN ${CONTENT_CHANNEL}`);
      const { rows } = await client.query<{ version: string }>(
        'select version from content_state where id = 1',
      );
      this.client = client;
      this.attempt = 0;
      const current = Number(rows[0]?.version ?? 0);
      if (this.lastEmitted === 0) this.lastEmitted = current;
      else if (current > this.lastEmitted) this.queue(current); // missed while disconnected
      this.options.logger.info({ version: current }, 'content listener connected');
    } catch (err) {
      this.options.logger.warn(
        { err: { message: (err as Error).message } },
        'content listener connect failed',
      );
      this.scheduleReconnect(client);
    }
  }

  private queue(version: number): void {
    this.pendingVersion = Math.max(this.pendingVersion ?? 0, version);
    if (this.coalesceTimer) return;
    this.coalesceTimer = setTimeout(() => {
      this.coalesceTimer = null;
      const next = this.pendingVersion;
      this.pendingVersion = null;
      if (next !== null && next > this.lastEmitted) {
        this.lastEmitted = next;
        this.emit('change', next);
      }
    }, this.coalesceMs);
  }

  private scheduleReconnect(client: pg.Client): void {
    if (this.stopped || this.reconnectTimer || (this.client && this.client !== client)) return;
    this.client = null;
    client.removeAllListeners('end');
    client.end().catch(() => {});
    const delay = this.delays[Math.min(this.attempt, this.delays.length - 1)]!;
    this.attempt += 1;
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      void this.connect();
    }, delay);
    this.reconnectTimer.unref();
  }

  async stop(): Promise<void> {
    this.stopped = true;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    if (this.coalesceTimer) clearTimeout(this.coalesceTimer);
    const client = this.client;
    this.client = null;
    if (client) {
      client.removeAllListeners('end');
      await client.end().catch(() => {});
    }
  }
}
