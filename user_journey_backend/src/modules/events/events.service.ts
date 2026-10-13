import type { Response } from 'express';

export interface VersionSource {
  readonly version: number;
  on(event: 'change', listener: (version: number) => void): unknown;
  off(event: 'change', listener: (version: number) => void): unknown;
}

/** Serializes one Server-Sent Event frame. */
export function sseFrame(event: string, data: unknown): string {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

/**
 * Fans content-version changes out to connected SSE clients (SPEC §6.2):
 * `retry: 5000` + `hello` on connect, `content_changed` on every coalesced change, `ping` every heartbeat.
 */
export class EventsHub {
  private readonly clients = new Set<Response>();
  private heartbeat: NodeJS.Timeout | null = null;
  private readonly onChange = (version: number) => this.broadcast('content_changed', { version });

  constructor(
    private readonly source: VersionSource,
    private readonly heartbeatMs: number,
    private readonly currentVersion: () => Promise<number>,
  ) {
    source.on('change', this.onChange);
  }

  get clientCount(): number {
    return this.clients.size;
  }

  async connect(res: Response): Promise<void> {
    res.status(200);
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders();
    const version = this.source.version || (await this.currentVersion());
    res.write('retry: 5000\n\n');
    res.write(sseFrame('hello', { version }));
    this.clients.add(res);
    res.on('close', () => this.clients.delete(res));
    this.ensureHeartbeat();
  }

  private ensureHeartbeat(): void {
    if (this.heartbeat) return;
    this.heartbeat = setInterval(() => {
      if (this.clients.size === 0) return;
      this.broadcast('ping', {});
    }, this.heartbeatMs);
    this.heartbeat.unref();
  }

  broadcast(event: string, data: unknown): void {
    const frame = sseFrame(event, data);
    for (const client of this.clients) client.write(frame);
  }

  /** Ends every stream (graceful shutdown). */
  close(): void {
    this.source.off('change', this.onChange);
    if (this.heartbeat) clearInterval(this.heartbeat);
    this.heartbeat = null;
    for (const client of this.clients) client.end();
    this.clients.clear();
  }
}
